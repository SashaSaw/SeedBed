import Foundation
import DeviceActivity
import FamilyControls
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

/// Manages Screen Time usage monitoring for habit auto-completion
@Observable
final class ScreenTimeUsageManager {
    static let shared = ScreenTimeUsageManager()

    /// App Group identifier for sharing data between main app and extension
    private static let appGroupID = "group.com.incept5.SeedBed"

    /// Keys for shared UserDefaults
    private static let configsKey = "screenTimeHabitConfigs"
    private static let completedHabitsKey = "screenTimeCompletedHabits"
    private static let slippedHabitsKey = "screenTimeSlippedHabits"

    /// Shared UserDefaults for app <-> extension communication
    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupID) ?? .standard
    }

    private let activityCenter = DeviceActivityCenter()

    /// The activity name prefix for habit monitoring
    private let habitActivityPrefix = "sown.habit."

    private init() {}

    // MARK: - Monitoring

    /// Start monitoring usage for all Screen Time linked habits
    /// - Parameter habits: Array of habits with Screen Time configured
    func startMonitoringHabits(_ habits: [Habit]) {
        // Stop existing monitoring first
        stopAllMonitoring()

        // Filter to habits with Screen Time linked
        let linkedHabits = habits.filter { $0.isScreenTimeLinked && $0.isActive }
        guard !linkedHabits.isEmpty else { return }

        // Save configs to shared defaults for extension to read
        saveConfigs(for: linkedHabits)

        // Register DeviceActivityEvents for each habit
        for habit in linkedHabits {
            let appTokens = habit.screenTimeAppTokens
            guard !appTokens.isEmpty,
                  let targetMinutes = habit.screenTimeTarget else { continue }

            let activityName = DeviceActivityName(rawValue: "\(habitActivityPrefix)\(habit.id.uuidString)")

            // Create a schedule that covers the entire day
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: 0, minute: 0),
                intervalEnd: DateComponents(hour: 23, minute: 59),
                repeats: true
            )

            // Create event that triggers when usage threshold is reached
            let thresholdEvent = DeviceActivityEvent(
                applications: appTokens,
                threshold: DateComponents(minute: targetMinutes)
            )

            let eventName = DeviceActivityEvent.Name(rawValue: "threshold.\(habit.id.uuidString)")

            do {
                try activityCenter.startMonitoring(
                    activityName,
                    during: schedule,
                    events: [eventName: thresholdEvent]
                )
            } catch {
                print("ScreenTimeUsageManager: Failed to start monitoring for \(habit.name): \(error)")
            }
        }
    }

    /// Stop all habit usage monitoring
    func stopAllMonitoring() {
        // Get all currently monitored activities
        let monitoredActivities = activityCenter.activities

        // Filter to just our habit activities
        let habitActivities = monitoredActivities.filter {
            $0.rawValue.hasPrefix(habitActivityPrefix)
        }

        if !habitActivities.isEmpty {
            activityCenter.stopMonitoring(habitActivities)
        }

        // Clear configs
        sharedDefaults.removeObject(forKey: Self.configsKey)
    }

    /// Stop monitoring for a specific habit
    func stopMonitoringHabit(_ habit: Habit) {
        let activityName = DeviceActivityName(rawValue: "\(habitActivityPrefix)\(habit.id.uuidString)")
        activityCenter.stopMonitoring([activityName])
        removeConfig(forHabitId: habit.id.uuidString)
    }

    /// Remove a single habit's config from shared defaults so the extension
    /// can no longer act on it if a stale DeviceActivity event fires.
    private func removeConfig(forHabitId habitId: String) {
        guard let data = sharedDefaults.data(forKey: Self.configsKey),
              var configs = try? JSONDecoder().decode([HabitScreenTimeConfig].self, from: data) else {
            return
        }
        configs.removeAll { $0.habitId == habitId }
        if configs.isEmpty {
            sharedDefaults.removeObject(forKey: Self.configsKey)
        } else if let encoded = try? JSONEncoder().encode(configs) {
            sharedDefaults.set(encoded, forKey: Self.configsKey)
        }
    }

    // MARK: - Shared Defaults

    /// Save habit configurations to shared defaults for extension access
    private func saveConfigs(for habits: [Habit]) {
        let configs = habits.compactMap { habit -> HabitScreenTimeConfig? in
            guard let targetMinutes = habit.screenTimeTarget else { return nil }
            return HabitScreenTimeConfig(
                habitId: habit.id.uuidString,
                habitName: habit.name,
                targetMinutes: targetMinutes,
                isNegative: habit.type == .negative,
                blockOnExceed: habit.screenTimeBlockOnExceed,
                appTokenData: habit.screenTimeAppTokenData
            )
        }

        if let data = try? JSONEncoder().encode(configs) {
            sharedDefaults.set(data, forKey: Self.configsKey)
        }
    }

    /// Get habit IDs that have been completed via Screen Time today
    /// Format: "{habitId}_{yyyy-MM-dd}"
    func getCompletedHabitIds() -> Set<String> {
        guard let completed = sharedDefaults.array(forKey: Self.completedHabitsKey) as? [String] else {
            return []
        }

        let todayString = dateString(for: Date())
        return Set(completed.filter { $0.hasSuffix("_\(todayString)") }
            .compactMap { $0.components(separatedBy: "_").first })
    }

    /// Mark a habit as completed by Screen Time (called from extension)
    static func markHabitCompleted(habitId: String, date: Date = Date()) {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        var completed = defaults.array(forKey: completedHabitsKey) as? [String] ?? []

        let dateString = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }()

        let entry = "\(habitId)_\(dateString)"
        if !completed.contains(entry) {
            completed.append(entry)
            defaults.set(completed, forKey: completedHabitsKey)
        }
    }

    /// Clear completed habits for a date (called at midnight)
    func clearCompletedHabits(for date: Date) {
        guard var completed = sharedDefaults.array(forKey: Self.completedHabitsKey) as? [String] else {
            return
        }

        let dateStr = dateString(for: date)
        completed.removeAll { $0.hasSuffix("_\(dateStr)") }
        sharedDefaults.set(completed, forKey: Self.completedHabitsKey)
    }

    // MARK: - Slip Tracking (for negative habits)

    /// Get habit IDs that have been slipped via Screen Time today
    /// Format: "{habitId}_{yyyy-MM-dd}"
    func getSlippedHabitIds(for date: Date = Date()) -> Set<String> {
        guard let slipped = sharedDefaults.array(forKey: Self.slippedHabitsKey) as? [String] else {
            return []
        }

        let todayString = dateString(for: date)
        return Set(slipped.filter { $0.hasSuffix("_\(todayString)") }
            .compactMap { $0.components(separatedBy: "_").first })
    }

    /// Mark a negative habit as slipped by Screen Time (called from extension)
    static func markHabitSlipped(habitId: String, date: Date = Date()) {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        var slipped = defaults.array(forKey: slippedHabitsKey) as? [String] ?? []

        let dateString = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }()

        let entry = "\(habitId)_\(dateString)"
        if !slipped.contains(entry) {
            slipped.append(entry)
            defaults.set(slipped, forKey: slippedHabitsKey)
        }
    }

    /// Clear slipped habits for a date (called at midnight)
    func clearSlippedHabits(for date: Date) {
        guard var slipped = sharedDefaults.array(forKey: Self.slippedHabitsKey) as? [String] else {
            return
        }

        let dateStr = dateString(for: date)
        slipped.removeAll { $0.hasSuffix("_\(dateStr)") }
        sharedDefaults.set(slipped, forKey: Self.slippedHabitsKey)
    }

    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Notifications

    /// Send a local notification when a Screen Time goal is achieved
    func sendAchievementNotification(habitName: String, minutes: Int) {
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
                print("Failed to send Screen Time notification: \(error)")
            }
        }
    }
}
