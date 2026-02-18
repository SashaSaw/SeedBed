import Foundation

/// Persistent singleton for user's daily schedule (wake/bed times)
/// Used by SmartReminderService and notification system to calculate reminder times
@Observable
final class UserSchedule {
    static let shared = UserSchedule()

    /// Minutes from midnight for wake time (default 7:00 AM = 420)
    var wakeTimeMinutes: Int {
        didSet {
            save()
            // Sync to cloud if enabled
            CloudSettingsService.shared.updateSetting("userWakeTimeMinutes", value: wakeTimeMinutes)
        }
    }

    /// Minutes from midnight for bed time (default 11:00 PM = 1380)
    var bedTimeMinutes: Int {
        didSet {
            save()
            // Sync to cloud if enabled
            CloudSettingsService.shared.updateSetting("userBedTimeMinutes", value: bedTimeMinutes)
        }
    }

    /// Whether smart reminders are enabled globally
    var smartRemindersEnabled: Bool {
        didSet {
            save()
            // Sync to cloud if enabled
            CloudSettingsService.shared.updateSetting("smartRemindersEnabled", value: smartRemindersEnabled)
        }
    }

    // MARK: - Computed Times

    /// Wake time as hour:minute
    var wakeHour: Int { wakeTimeMinutes / 60 }
    var wakeMinute: Int { wakeTimeMinutes % 60 }

    /// Bed time as hour:minute
    var bedHour: Int { bedTimeMinutes / 60 }
    var bedMinute: Int { bedTimeMinutes % 60 }

    /// Wake time as a Date (today)
    var wakeTimeDate: Date {
        Calendar.current.date(from: DateComponents(hour: wakeHour, minute: wakeMinute)) ?? Date()
    }

    /// Bed time as a Date (today)
    var bedTimeDate: Date {
        Calendar.current.date(from: DateComponents(hour: bedHour, minute: bedMinute)) ?? Date()
    }

    /// Formatted wake time string (e.g. "7:00 AM")
    var wakeTimeString: String {
        formatMinutes(wakeTimeMinutes)
    }

    /// Formatted bed time string (e.g. "11:00 PM")
    var bedTimeString: String {
        formatMinutes(bedTimeMinutes)
    }

    // MARK: - Smart Reminder Times (5 daily)

    /// Reminder 1: At wake time — "Start your morning habits"
    var reminder1Minutes: Int { wakeTimeMinutes }

    /// Reminder 2: 11:00 AM — "One hour before morning ends, finish morning habits"
    var reminder2Minutes: Int { 11 * 60 } // 660

    /// Reminder 3: 5:00 PM — "Get your daytime habits done"
    var reminder3Minutes: Int { 17 * 60 } // 1020

    /// Reminder 4: 2 hours before bed — "Evening wind-down, finish hobbies"
    var reminder4Minutes: Int { max(bedTimeMinutes - 120, 18 * 60) }

    /// Reminder 5: 1 hour before bed — "Last call, finish before bed habits"
    var reminder5Minutes: Int { max(bedTimeMinutes - 60, 19 * 60) }

    /// All 5 reminder times as (minutes, slot description)
    var allReminderSlots: [(minutes: Int, label: String, timeOfDayFilter: String)] {
        [
            (reminder1Minutes, "Wake up", "After Wake"),
            (reminder2Minutes, "Late morning", "Morning"),
            (reminder3Minutes, "Afternoon", "During the Day"),
            (reminder4Minutes, "Evening", "Evening"),
            (reminder5Minutes, "Before bed", "Before Bed"),
        ]
    }

    // MARK: - Init & Persistence

    private let defaults = UserDefaults.standard
    private let wakeKey = "userWakeTimeMinutes"
    private let bedKey = "userBedTimeMinutes"
    private let remindersKey = "smartRemindersEnabled"

    private init() {
        let storedWake = defaults.integer(forKey: wakeKey)
        let storedBed = defaults.integer(forKey: bedKey)

        self.wakeTimeMinutes = storedWake > 0 ? storedWake : 420    // 7:00 AM
        self.bedTimeMinutes = storedBed > 0 ? storedBed : 1380      // 11:00 PM
        self.smartRemindersEnabled = defaults.bool(forKey: remindersKey)

        // Listen for cloud settings changes
        NotificationCenter.default.addObserver(
            forName: .scheduleSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadFromDefaults()
        }
    }

    /// Reload values from UserDefaults (called when cloud sync updates values)
    private func reloadFromDefaults() {
        let storedWake = defaults.integer(forKey: wakeKey)
        let storedBed = defaults.integer(forKey: bedKey)

        // Only update if values are different (avoid infinite loop from didSet)
        if storedWake > 0 && storedWake != wakeTimeMinutes {
            wakeTimeMinutes = storedWake
        }
        if storedBed > 0 && storedBed != bedTimeMinutes {
            bedTimeMinutes = storedBed
        }

        let storedReminders = defaults.bool(forKey: remindersKey)
        if storedReminders != smartRemindersEnabled {
            smartRemindersEnabled = storedReminders
        }
    }

    private func save() {
        defaults.set(wakeTimeMinutes, forKey: wakeKey)
        defaults.set(bedTimeMinutes, forKey: bedKey)
        defaults.set(smartRemindersEnabled, forKey: remindersKey)
    }

    /// Update from onboarding data
    func updateFromOnboarding(wakeTime: Date, bedTime: Date) {
        let calendar = Calendar.current
        let wakeComps = calendar.dateComponents([.hour, .minute], from: wakeTime)
        let bedComps = calendar.dateComponents([.hour, .minute], from: bedTime)

        wakeTimeMinutes = (wakeComps.hour ?? 7) * 60 + (wakeComps.minute ?? 0)
        bedTimeMinutes = (bedComps.hour ?? 23) * 60 + (bedComps.minute ?? 0)
    }

    // MARK: - Helpers

    private func formatMinutes(_ totalMinutes: Int) -> String {
        let hour = totalMinutes / 60
        let minute = totalMinutes % 60
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
}
