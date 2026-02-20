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
}

/// DeviceActivityMonitor extension that applies/removes shields when the blocking schedule begins/ends
/// and handles habit usage threshold events for auto-completion
/// NOTE: Class name must match NSExtensionPrincipalClass in Info.plist
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()
    private static let selectionKey = "screenTimeSelection"
    private static let appGroupID = "group.com.incept5.SeedBed"
    private static let configsKey = "screenTimeHabitConfigs"
    private static let completedHabitsKey = "screenTimeCompletedHabits"

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        // Check if this is a blocking schedule (not a habit monitoring activity)
        guard activity.rawValue == "sown.blocking" else { return }

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
        guard activity.rawValue == "sown.blocking" else { return }

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

        // Load habit configs to get the habit name
        let configs = loadHabitConfigs()
        let config = configs.first { $0.habitId == habitIdString }

        // Mark habit as completed in shared defaults
        markHabitCompleted(habitId: habitIdString)

        // Send notification immediately (extension runs in background)
        if let config = config {
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

    // MARK: - Load Selection

    /// Load FamilyActivitySelection from the shared App Group UserDefaults
    private func loadSelection() -> FamilyActivitySelection? {
        let defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        guard let data = defaults.data(forKey: Self.selectionKey) else { return nil }
        return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    }
}
