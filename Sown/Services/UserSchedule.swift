import Foundation

/// Persistent singleton for user's daily schedule (wake/bed times)
/// Used by UnifiedNotificationService to calculate per-habit notification times
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

    /// Whether notifications are enabled globally (master toggle)
    var notificationsEnabled: Bool {
        didSet {
            save()
            CloudSettingsService.shared.updateSetting("smartRemindersEnabled", value: notificationsEnabled)
        }
    }

    /// Legacy accessor — maps to notificationsEnabled for backwards compatibility
    var smartRemindersEnabled: Bool {
        get { notificationsEnabled }
        set { notificationsEnabled = newValue }
    }

    // MARK: - Per-Slot Enabled Toggles

    var slotAfterWakeEnabled: Bool {
        didSet { saveSlotToggles(); CloudSettingsService.shared.updateSetting("slotAfterWakeEnabled", value: slotAfterWakeEnabled) }
    }
    var slotMorningEnabled: Bool {
        didSet { saveSlotToggles(); CloudSettingsService.shared.updateSetting("slotMorningEnabled", value: slotMorningEnabled) }
    }
    var slotDaytimeEnabled: Bool {
        didSet { saveSlotToggles(); CloudSettingsService.shared.updateSetting("slotDaytimeEnabled", value: slotDaytimeEnabled) }
    }
    var slotEveningEnabled: Bool {
        didSet { saveSlotToggles(); CloudSettingsService.shared.updateSetting("slotEveningEnabled", value: slotEveningEnabled) }
    }
    var slotBeforeBedEnabled: Bool {
        didSet { saveSlotToggles(); CloudSettingsService.shared.updateSetting("slotBeforeBedEnabled", value: slotBeforeBedEnabled) }
    }

    /// Returns whether notifications are enabled for a given slot index (0-4)
    func isSlotEnabled(_ index: Int) -> Bool {
        switch index {
        case 0: return slotAfterWakeEnabled
        case 1: return slotMorningEnabled
        case 2: return slotDaytimeEnabled
        case 3: return slotEveningEnabled
        case 4: return slotBeforeBedEnabled
        default: return true
        }
    }

    /// Sets whether notifications are enabled for a given slot index
    func setSlotEnabled(_ index: Int, enabled: Bool) {
        switch index {
        case 0: slotAfterWakeEnabled = enabled
        case 1: slotMorningEnabled = enabled
        case 2: slotDaytimeEnabled = enabled
        case 3: slotEveningEnabled = enabled
        case 4: slotBeforeBedEnabled = enabled
        default: break
        }
    }

    /// Returns the notification time (minutes from midnight) for a given slot index
    func timeForSlot(_ index: Int) -> Int {
        switch index {
        case 0: return reminder1Minutes
        case 1: return reminder2Minutes
        case 2: return reminder3Minutes
        case 3: return reminder4Minutes
        case 4: return reminder5Minutes
        default: return 0
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

    /// Effective bedtime in minutes, accounting for past-midnight bedtimes.
    /// If bedtime < wake time (e.g. 1am bed, 7am wake), adds 1440 so arithmetic works.
    private var effectiveBedTimeMinutes: Int {
        bedTimeMinutes < wakeTimeMinutes ? bedTimeMinutes + 1440 : bedTimeMinutes
    }

    /// Default reminder 1: At wake time
    var reminder1Default: Int { wakeTimeMinutes }
    /// Default reminder 2: 11:00 AM
    var reminder2Default: Int { 11 * 60 }
    /// Default reminder 3: 5:00 PM
    var reminder3Default: Int { 17 * 60 }
    /// Default reminder 4: 2 hours before bed
    var reminder4Default: Int { (effectiveBedTimeMinutes - 120) % 1440 }
    /// Default reminder 5: 1 hour before bed
    var reminder5Default: Int { (effectiveBedTimeMinutes - 60) % 1440 }

    /// Reminder 1: At wake time — "Start your morning habits"
    var reminder1Minutes: Int { reminder1Override ?? reminder1Default }

    /// Reminder 2: 11:00 AM — "One hour before morning ends, finish morning habits"
    var reminder2Minutes: Int { reminder2Override ?? reminder2Default }

    /// Reminder 3: 5:00 PM — "Get your daytime habits done"
    var reminder3Minutes: Int { reminder3Override ?? reminder3Default }

    /// Reminder 4: 2 hours before bed — "Evening wind-down, finish hobbies"
    var reminder4Minutes: Int { reminder4Override ?? reminder4Default }

    /// Reminder 5: 1 hour before bed — "Last call, finish before bed habits"
    var reminder5Minutes: Int { reminder5Override ?? reminder5Default }

    // MARK: - Reminder Overrides (nil = use default)

    var reminder1Override: Int? {
        didSet { saveOverrides(); CloudSettingsService.shared.updateSetting("reminder1Override", value: reminder1Override ?? -1) }
    }
    var reminder2Override: Int? {
        didSet { saveOverrides(); CloudSettingsService.shared.updateSetting("reminder2Override", value: reminder2Override ?? -1) }
    }
    var reminder3Override: Int? {
        didSet { saveOverrides(); CloudSettingsService.shared.updateSetting("reminder3Override", value: reminder3Override ?? -1) }
    }
    var reminder4Override: Int? {
        didSet { saveOverrides(); CloudSettingsService.shared.updateSetting("reminder4Override", value: reminder4Override ?? -1) }
    }
    var reminder5Override: Int? {
        didSet { saveOverrides(); CloudSettingsService.shared.updateSetting("reminder5Override", value: reminder5Override ?? -1) }
    }

    /// Whether a given reminder slot has a user override
    func hasOverride(for index: Int) -> Bool {
        switch index {
        case 0: return reminder1Override != nil
        case 1: return reminder2Override != nil
        case 2: return reminder3Override != nil
        case 3: return reminder4Override != nil
        case 4: return reminder5Override != nil
        default: return false
        }
    }

    /// Reset a reminder slot back to its default
    func resetReminderToDefault(_ index: Int) {
        switch index {
        case 0: reminder1Override = nil
        case 1: reminder2Override = nil
        case 2: reminder3Override = nil
        case 3: reminder4Override = nil
        case 4: reminder5Override = nil
        default: break
        }
    }

    /// Set a custom override for a reminder slot (minutes from midnight)
    func setReminderOverride(_ index: Int, minutes: Int) {
        switch index {
        case 0: reminder1Override = minutes
        case 1: reminder2Override = minutes
        case 2: reminder3Override = minutes
        case 3: reminder4Override = minutes
        case 4: reminder5Override = minutes
        default: break
        }
    }

    /// Default time for a reminder slot (minutes from midnight)
    func defaultMinutes(for index: Int) -> Int {
        switch index {
        case 0: return reminder1Default
        case 1: return reminder2Default
        case 2: return reminder3Default
        case 3: return reminder4Default
        case 4: return reminder5Default
        default: return 0
        }
    }

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
    private let overrideKeys = (1...5).map { "reminder\($0)Override" }
    private let slotToggleKeys = ["slotAfterWakeEnabled", "slotMorningEnabled", "slotDaytimeEnabled", "slotEveningEnabled", "slotBeforeBedEnabled"]

    private init() {
        let storedWake = defaults.integer(forKey: wakeKey)
        let storedBed = defaults.integer(forKey: bedKey)

        self.wakeTimeMinutes = storedWake > 0 ? storedWake : 420    // 7:00 AM
        self.bedTimeMinutes = storedBed > 0 ? storedBed : 1380      // 11:00 PM
        self.notificationsEnabled = defaults.bool(forKey: remindersKey)

        // Load per-slot enabled toggles (default to true if never set)
        self.slotAfterWakeEnabled = defaults.object(forKey: slotToggleKeys[0]) == nil ? true : defaults.bool(forKey: slotToggleKeys[0])
        self.slotMorningEnabled = defaults.object(forKey: slotToggleKeys[1]) == nil ? true : defaults.bool(forKey: slotToggleKeys[1])
        self.slotDaytimeEnabled = defaults.object(forKey: slotToggleKeys[2]) == nil ? true : defaults.bool(forKey: slotToggleKeys[2])
        self.slotEveningEnabled = defaults.object(forKey: slotToggleKeys[3]) == nil ? true : defaults.bool(forKey: slotToggleKeys[3])
        self.slotBeforeBedEnabled = defaults.object(forKey: slotToggleKeys[4]) == nil ? true : defaults.bool(forKey: slotToggleKeys[4])

        // Load reminder overrides (-1 means nil/no override)
        self.reminder1Override = loadOverride(index: 0)
        self.reminder2Override = loadOverride(index: 1)
        self.reminder3Override = loadOverride(index: 2)
        self.reminder4Override = loadOverride(index: 3)
        self.reminder5Override = loadOverride(index: 4)

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
        if storedReminders != notificationsEnabled {
            notificationsEnabled = storedReminders
        }

        // Reload slot toggles
        for (i, key) in slotToggleKeys.enumerated() {
            if defaults.object(forKey: key) != nil {
                let val = defaults.bool(forKey: key)
                if val != isSlotEnabled(i) {
                    setSlotEnabled(i, enabled: val)
                }
            }
        }

        // Reload overrides
        reminder1Override = loadOverride(index: 0)
        reminder2Override = loadOverride(index: 1)
        reminder3Override = loadOverride(index: 2)
        reminder4Override = loadOverride(index: 3)
        reminder5Override = loadOverride(index: 4)
    }

    private func save() {
        defaults.set(wakeTimeMinutes, forKey: wakeKey)
        defaults.set(bedTimeMinutes, forKey: bedKey)
        defaults.set(notificationsEnabled, forKey: remindersKey)
    }

    private func saveSlotToggles() {
        defaults.set(slotAfterWakeEnabled, forKey: slotToggleKeys[0])
        defaults.set(slotMorningEnabled, forKey: slotToggleKeys[1])
        defaults.set(slotDaytimeEnabled, forKey: slotToggleKeys[2])
        defaults.set(slotEveningEnabled, forKey: slotToggleKeys[3])
        defaults.set(slotBeforeBedEnabled, forKey: slotToggleKeys[4])
    }

    /// Update from onboarding data
    func updateFromOnboarding(wakeTime: Date, bedTime: Date) {
        let calendar = Calendar.current
        let wakeComps = calendar.dateComponents([.hour, .minute], from: wakeTime)
        let bedComps = calendar.dateComponents([.hour, .minute], from: bedTime)

        wakeTimeMinutes = (wakeComps.hour ?? 7) * 60 + (wakeComps.minute ?? 0)
        bedTimeMinutes = (bedComps.hour ?? 23) * 60 + (bedComps.minute ?? 0)
    }

    // MARK: - Override Persistence

    private func loadOverride(index: Int) -> Int? {
        let key = overrideKeys[index]
        let val = defaults.integer(forKey: key)
        // 0 is the default for unset keys; use -1 sentinel for "no override"
        // If key was never set, defaults.integer returns 0 — treat as nil
        if defaults.object(forKey: key) == nil { return nil }
        return val >= 0 ? val : nil
    }

    private func saveOverrides() {
        let overrides: [Int?] = [reminder1Override, reminder2Override, reminder3Override, reminder4Override, reminder5Override]
        for (i, override_) in overrides.enumerated() {
            if let minutes = override_ {
                defaults.set(minutes, forKey: overrideKeys[i])
            } else {
                defaults.removeObject(forKey: overrideKeys[i])
            }
        }
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
