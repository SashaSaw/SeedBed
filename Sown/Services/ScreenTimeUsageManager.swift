import Foundation
import DeviceActivity
import FamilyControls
import UserNotifications

/// Configuration for a habit's screen time tracking, shared between app and extension
struct HabitScreenTimeConfig: Codable {
    let habitId: String
    let habitName: String
    let targetMinutes: Int
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
            guard let appToken = habit.screenTimeAppToken,
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
                applications: [appToken],
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
    }

    // MARK: - Shared Defaults

    /// Save habit configurations to shared defaults for extension access
    private func saveConfigs(for habits: [Habit]) {
        let configs = habits.compactMap { habit -> HabitScreenTimeConfig? in
            guard let targetMinutes = habit.screenTimeTarget else { return nil }
            return HabitScreenTimeConfig(
                habitId: habit.id.uuidString,
                habitName: habit.name,
                targetMinutes: targetMinutes
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
