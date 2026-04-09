import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation
import UserNotifications

/// Configuration for a habit's screen time tracking, shared between app and extension
struct HabitScreenTimeConfig: Codable {
    let habitId: String
    let habitName: String
    let targetMinutes: Int
    let isNegative: Bool       // For Don't Do habits that slip when limit exceeded
    let blockOnExceed: Bool    // Whether to block the app after limit exceeded
    var appTokenData: Data?    // Serialized ApplicationToken for blocking

    init(habitId: String, habitName: String, targetMinutes: Int, isNegative: Bool = false, blockOnExceed: Bool = false, appTokenData: Data? = nil) {
        self.habitId = habitId
        self.habitName = habitName
        self.targetMinutes = targetMinutes
        self.isNegative = isNegative
        self.blockOnExceed = blockOnExceed
        self.appTokenData = appTokenData
    }
}

/// DeviceActivityMonitor extension that applies/removes shields when the blocking schedule begins/ends
/// and handles habit usage threshold events for auto-completion
/// NOTE: Class name must match NSExtensionPrincipalClass in Info.plist
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore(named: .init("sown.blocking"))
    private let failureStore = ManagedSettingsStore(named: .init("sown.failure"))
    private static let selectionKey = "screenTimeSelection"
    private static let appGroupID = "group.com.incept5.SeedBed"
    private static let configsKey = "screenTimeHabitConfigs"
    private static let completedHabitsKey = "screenTimeCompletedHabits"
    private static let slippedHabitsKey = "screenTimeSlippedHabits"
    private static let failureBlockedAppsKey = "failureBlockedApps"

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        // Check if this is a blocking schedule (not a habit monitoring activity)
        guard activity.rawValue == "sown.blocking" || activity.rawValue.hasPrefix("sown.block.") else { return }

        // Day-of-week guard for per-day activities
        if activity.rawValue.hasPrefix("sown.block.") {
            let parts = activity.rawValue.split(separator: ".")
            if parts.count >= 3, let dayOfWeek = Int(parts[2]) {
                let currentWeekday = Calendar.current.component(.weekday, from: Date())
                guard dayOfWeek == currentWeekday else { return }
            }
        }

        // Only apply shields if blocking is enabled (shared via App Group)
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        guard defaults?.bool(forKey: "blockingIsEnabled") == true else { return }

        // Load the saved selection and apply shields
        guard let selection = loadSelection() else { return }

        let applications = selection.applicationTokens
        let categories = selection.categoryTokens

        if !applications.isEmpty {
            store.shield.applications = applications
        }
        if !categories.isEmpty {
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy<Application>.specific(categories)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        // Check if this is a blocking schedule
        guard activity.rawValue == "sown.blocking" || activity.rawValue.hasPrefix("sown.block.") else { return }

        // Day-of-week guard for per-day activities
        if activity.rawValue.hasPrefix("sown.block.") {
            let parts = activity.rawValue.split(separator: ".")
            if parts.count >= 3, let dayOfWeek = Int(parts[2]) {
                let currentWeekday = Calendar.current.component(.weekday, from: Date())
                guard dayOfWeek == currentWeekday else { return }
            }
        }

        // Remove all shields when the schedule ends
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        // Check if this is a habit usage threshold event
        let eventString = event.rawValue
        guard eventString.hasPrefix("threshold.") else { return }

        // Extract habit ID from event name
        let habitIdString = String(eventString.dropFirst("threshold.".count))

        // Load habit configs to get the habit config
        let configs = loadHabitConfigs()
        guard let config = configs.first(where: { $0.habitId == habitIdString }) else { return }

        if config.isNegative {
            // This is a Don't Do habit - mark as SLIPPED (not completed)
            markHabitSlipped(habitId: habitIdString)

            // Block the app if configured
            if config.blockOnExceed, let appTokenData = config.appTokenData {
                blockAppForFailure(appTokenData: appTokenData, habitId: habitIdString, habitName: config.habitName, targetMinutes: config.targetMinutes)
            }

            // Send slip notification
            sendSlipNotification(habitName: config.habitName, minutes: config.targetMinutes)
        } else {
            // Existing positive completion logic
            markHabitCompleted(habitId: habitIdString)

            // Send achievement notification
            sendAchievementNotification(habitName: config.habitName, minutes: config.targetMinutes)
        }
    }

    // MARK: - Habit Completion

    /// Mark a habit as completed by Screen Time
    private func markHabitCompleted(habitId: String) {
        let defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        var completed = defaults.array(forKey: Self.completedHabitsKey) as? [String] ?? []

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())

        let entry = "\(habitId)_\(dateString)"
        if !completed.contains(entry) {
            completed.append(entry)
            defaults.set(completed, forKey: Self.completedHabitsKey)
        }
    }

    // MARK: - Habit Slip (for negative habits)

    /// Mark a negative habit as slipped by Screen Time
    private func markHabitSlipped(habitId: String) {
        let defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        var slipped = defaults.array(forKey: Self.slippedHabitsKey) as? [String] ?? []

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())

        let entry = "\(habitId)_\(dateString)"
        if !slipped.contains(entry) {
            slipped.append(entry)
            defaults.set(slipped, forKey: Self.slippedHabitsKey)
        }
    }

    // MARK: - Per-App Blocking

    /// Block a specific app due to exceeding Don't Do limit.
    /// Uses the failure store (separate from schedule store) — persists until midnight.
    private func blockAppForFailure(appTokenData: Data, habitId: String, habitName: String, targetMinutes: Int) {
        // appTokenData is a PropertyList-encoded Set<ApplicationToken> (can contain multiple apps)
        // Fall back to single token decoding for backward compatibility
        let appTokens: Set<ApplicationToken>
        if let tokenSet = try? PropertyListDecoder().decode(Set<ApplicationToken>.self, from: appTokenData) {
            appTokens = tokenSet
        } else if let singleToken = try? PropertyListDecoder().decode(ApplicationToken.self, from: appTokenData) {
            appTokens = [singleToken]
        } else {
            return
        }

        guard !appTokens.isEmpty else { return }

        // Add apps to the failure store (separate from schedule shields)
        var currentApps = failureStore.shield.applications ?? Set()
        currentApps.formUnion(appTokens)
        failureStore.shield.applications = currentApps

        // Save individual token data to shared defaults so the main app can track and clear
        let defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        var blockedAppsData = defaults.array(forKey: Self.failureBlockedAppsKey) as? [Data] ?? []
        // Store each token individually for the main app's loadFailureBlockedApps()
        for token in appTokens {
            if let tokenData = try? PropertyListEncoder().encode(token),
               !blockedAppsData.contains(tokenData) {
                blockedAppsData.append(tokenData)
            }
        }
        defaults.set(blockedAppsData, forKey: Self.failureBlockedAppsKey)

        // Store habit info for shield message and Block tab banner
        var habitInfo = defaults.array(forKey: "failureBlockedHabitInfo") as? [[String: Any]] ?? []
        let entry: [String: Any] = ["habitId": habitId, "habitName": habitName, "targetMinutes": targetMinutes]
        if !habitInfo.contains(where: { ($0["habitId"] as? String) == habitId }) {
            habitInfo.append(entry)
            defaults.set(habitInfo, forKey: "failureBlockedHabitInfo")
        }
    }

    /// Load habit configurations from shared defaults
    private func loadHabitConfigs() -> [HabitScreenTimeConfig] {
        let defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        guard let data = defaults.data(forKey: Self.configsKey) else { return [] }
        return (try? JSONDecoder().decode([HabitScreenTimeConfig].self, from: data)) ?? []
    }

    // MARK: - Notifications

    /// Send a local notification when a Screen Time goal is achieved
    private func sendAchievementNotification(habitName: String, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Screen Time Goal Reached!"
        content.body = "\(habitName) completed - you spent \(minutes) minutes in the app!"
        content.sound = .default
        content.categoryIdentifier = "SCREENTIME_ACHIEVEMENT"

        let request = UNNotificationRequest(
            identifier: "screentime_\(UUID().uuidString)",
            content: content,
            trigger: nil // Immediate
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("DeviceActivityMonitor: Failed to send notification: \(error)")
            }
        }
    }

    /// Send a local notification when a Don't Do habit limit is exceeded
    private func sendSlipNotification(habitName: String, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Don't-do limit exceeded"
        content.body = "\(habitName) — you spent \(minutes) minutes. Habit marked as slipped."
        content.sound = .default
        content.categoryIdentifier = "SCREENTIME_SLIP"

        let request = UNNotificationRequest(
            identifier: "screentime_slip_\(UUID().uuidString)",
            content: content,
            trigger: nil // Immediate
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("DeviceActivityMonitor: Failed to send slip notification: \(error)")
            }
        }
    }

    // MARK: - Load Selection

    /// Load FamilyActivitySelection from the shared App Group UserDefaults
    private func loadSelection() -> FamilyActivitySelection? {
        let defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        guard let data = defaults.data(forKey: Self.selectionKey) else { return nil }
        return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    }
}
