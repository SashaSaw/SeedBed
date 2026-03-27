import Foundation
import FamilyControls
import SwiftUI

// MARK: - Supporting Types

enum BlockingType: String, Codable, CaseIterable {
    case fullBlock = "fullBlock"
    case timedUnlock = "timedUnlock"
}

struct BlockScheduleEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var dayOfWeek: Int       // 1=Sun...7=Sat
    var startMinutes: Int    // minutes from midnight
    var endMinutes: Int      // minutes from midnight

    init(id: UUID = UUID(), dayOfWeek: Int, startMinutes: Int, endMinutes: Int) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
    }
}

/// Manages app blocking settings persisted via UserDefaults
@Observable
final class BlockSettings {
    static let shared = BlockSettings()

    /// Guard flag to prevent recursive sync between entries and legacy fields
    private var isSyncing = false

    /// Whether blocking is enabled globally
    var isEnabled: Bool {
        didSet {
            save()
            CloudSettingsService.shared.setBlockingFlag(isEnabled)
        }
    }

    /// Block schedule start time (minutes from midnight) — legacy, kept for backward compat
    var scheduleStartMinutes: Int {
        didSet {
            guard !isSyncing else { return }
            syncEntriesToLegacy()
            save()
        }
    }

    /// Block schedule end time (minutes from midnight) — legacy, kept for backward compat
    var scheduleEndMinutes: Int {
        didSet {
            guard !isSyncing else { return }
            syncEntriesToLegacy()
            save()
        }
    }

    /// Which days of the week blocking is active (1=Sun, 7=Sat) — legacy, kept for backward compat
    var activeDays: Set<Int> {
        didSet {
            guard !isSyncing else { return }
            syncEntriesToLegacy()
            save()
        }
    }

    /// Blocking mode: full block or timed unlock
    var blockingType: BlockingType {
        didSet { save() }
    }

    /// Per-day schedule entries
    var scheduleEntries: [BlockScheduleEntry] {
        didSet { save() }
    }

    /// Temporary unlock: app name → expiry date
    var temporaryUnlocks: [String: Date] {
        didSet { save() }
    }

    /// Date when negative habits were auto-slipped via the intercept unlock flow.
    /// When set to today's date, negative habits cannot be toggled back.
    var negativeHabitsAutoSlippedDate: Date? {
        didSet { save() }
    }

    // MARK: - Computed Properties

    /// Number of selected apps + categories from Screen Time selection
    var selectedCount: Int {
        let stm = ScreenTimeManager.shared
        return stm.activitySelection.applicationTokens.count
            + stm.activitySelection.categoryTokens.count
    }

    /// Human-readable summary of selected apps and categories (e.g. "2 apps, 1 category")
    var selectionSummary: String {
        let stm = ScreenTimeManager.shared
        let apps = stm.activitySelection.applicationTokens.count
        let cats = stm.activitySelection.categoryTokens.count
        var parts: [String] = []
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if cats > 0 { parts.append("\(cats) categor\(cats == 1 ? "y" : "ies")") }
        return parts.joined(separator: ", ")
    }

    /// Formatted start time string
    var startTimeString: String {
        formatMinutes(scheduleStartMinutes)
    }

    /// Formatted end time string
    var endTimeString: String {
        formatMinutes(scheduleEndMinutes)
    }

    /// Start time as Date (today)
    var startTime: Date {
        get {
            Calendar.current.date(bySettingHour: scheduleStartMinutes / 60, minute: scheduleStartMinutes % 60, second: 0, of: Date()) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            scheduleStartMinutes = (components.hour ?? 9) * 60 + (components.minute ?? 0)
        }
    }

    /// End time as Date (today)
    var endTime: Date {
        get {
            Calendar.current.date(bySettingHour: scheduleEndMinutes / 60, minute: scheduleEndMinutes % 60, second: 0, of: Date()) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            scheduleEndMinutes = (components.hour ?? 21) * 60 + (components.minute ?? 0)
        }
    }

    /// Whether blocking is currently active (within schedule and has selections)
    var isCurrentlyActive: Bool {
        guard isEnabled, selectedCount > 0 else { return false }

        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        // Check schedule entries for today's weekday
        let todayEntries = scheduleEntries.filter { $0.dayOfWeek == weekday }
        for entry in todayEntries {
            if entry.startMinutes <= entry.endMinutes {
                if currentMinutes >= entry.startMinutes && currentMinutes < entry.endMinutes {
                    return true
                }
            } else {
                // Wraps midnight
                if currentMinutes >= entry.startMinutes || currentMinutes < entry.endMinutes {
                    return true
                }
            }
        }

        return false
    }

    /// Time remaining in current block window
    var timeRemainingString: String? {
        guard isCurrentlyActive else { return nil }

        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        // Find the active entry
        let todayEntries = scheduleEntries.filter { $0.dayOfWeek == weekday }
        for entry in todayEntries {
            let isInEntry: Bool
            if entry.startMinutes <= entry.endMinutes {
                isInEntry = currentMinutes >= entry.startMinutes && currentMinutes < entry.endMinutes
            } else {
                isInEntry = currentMinutes >= entry.startMinutes || currentMinutes < entry.endMinutes
            }

            if isInEntry {
                let remaining: Int
                if entry.startMinutes <= entry.endMinutes {
                    remaining = entry.endMinutes - currentMinutes
                } else {
                    if currentMinutes >= entry.startMinutes {
                        remaining = (24 * 60 - currentMinutes) + entry.endMinutes
                    } else {
                        remaining = entry.endMinutes - currentMinutes
                    }
                }

                let hours = remaining / 60
                let minutes = remaining % 60

                if hours > 0 {
                    return "\(hours)h \(minutes)m left"
                } else {
                    return "\(minutes)m left"
                }
            }
        }

        return nil
    }

    /// Next block time string (when blocking is off)
    var nextBlockTimeString: String? {
        guard isEnabled, !isCurrentlyActive else { return nil }

        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        // Check today first
        let todayEntries = scheduleEntries.filter { $0.dayOfWeek == weekday }
        for entry in todayEntries.sorted(by: { $0.startMinutes < $1.startMinutes }) {
            if entry.startMinutes > currentMinutes {
                return "Next block at \(formatMinutes(entry.startMinutes))"
            }
        }

        // Check upcoming days
        for offset in 1...7 {
            let nextWeekday = ((weekday - 1 + offset) % 7) + 1
            let dayEntries = scheduleEntries.filter { $0.dayOfWeek == nextWeekday }
            if let first = dayEntries.sorted(by: { $0.startMinutes < $1.startMinutes }).first {
                let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                let dayName = dayNames[nextWeekday - 1]
                return "Next block \(dayName) at \(formatMinutes(first.startMinutes))"
            }
        }

        return nil
    }

    /// Whether negative habits were auto-slipped today (and cannot be toggled back)
    var areNegativeHabitsLockedToday: Bool {
        guard let slippedDate = negativeHabitsAutoSlippedDate else { return false }
        return Calendar.current.isDateInToday(slippedDate)
    }

    /// Check if a specific app is temporarily unlocked
    func isTemporarilyUnlocked(_ appName: String) -> Bool {
        guard let expiry = temporaryUnlocks[appName] else { return false }
        return Date() < expiry
    }

    /// Grant a 5-minute temporary unlock for an app
    func grantTemporaryUnlock(for appName: String) {
        temporaryUnlocks[appName] = Date().addingTimeInterval(5 * 60)
    }

    /// Get the schedule entry for a specific day (returns the first one)
    func entry(for dayOfWeek: Int) -> BlockScheduleEntry? {
        scheduleEntries.first { $0.dayOfWeek == dayOfWeek }
    }

    /// Update or create a schedule entry for a specific day
    func updateEntry(dayOfWeek: Int, startMinutes: Int, endMinutes: Int) {
        if let index = scheduleEntries.firstIndex(where: { $0.dayOfWeek == dayOfWeek }) {
            scheduleEntries[index] = BlockScheduleEntry(
                id: scheduleEntries[index].id,
                dayOfWeek: dayOfWeek,
                startMinutes: startMinutes,
                endMinutes: endMinutes
            )
        } else {
            scheduleEntries.append(BlockScheduleEntry(
                dayOfWeek: dayOfWeek,
                startMinutes: startMinutes,
                endMinutes: endMinutes
            ))
        }
        // Sync legacy fields from active entries
        syncLegacyFromEntries()
    }

    /// Remove the schedule entry for a specific day
    func removeEntry(dayOfWeek: Int) {
        scheduleEntries.removeAll { $0.dayOfWeek == dayOfWeek }
        syncLegacyFromEntries()
    }

    /// Days that have a schedule entry
    var scheduledDays: Set<Int> {
        Set(scheduleEntries.map(\.dayOfWeek))
    }

    // MARK: - Persistence

    private static let settingsKeyV3 = "blockSettings_v3"
    private static let settingsKeyV2 = "blockSettings_v2"

    private init() {
        // Try v3 first
        if let data = UserDefaults.standard.data(forKey: Self.settingsKeyV3),
           let saved = try? JSONDecoder().decode(SavedBlockSettingsV3.self, from: data) {
            self.isEnabled = saved.isEnabled
            self.scheduleStartMinutes = saved.scheduleStartMinutes
            self.scheduleEndMinutes = saved.scheduleEndMinutes
            self.activeDays = Set(saved.activeDays)
            self.blockingType = saved.blockingType
            self.scheduleEntries = saved.scheduleEntries
            self.temporaryUnlocks = saved.temporaryUnlocks
            self.negativeHabitsAutoSlippedDate = saved.negativeHabitsAutoSlippedDate
        }
        // Migrate from v2
        else if let data = UserDefaults.standard.data(forKey: Self.settingsKeyV2),
                let saved = try? JSONDecoder().decode(SavedBlockSettingsV2.self, from: data) {
            self.isEnabled = saved.isEnabled
            self.scheduleStartMinutes = saved.scheduleStartMinutes
            self.scheduleEndMinutes = saved.scheduleEndMinutes
            self.activeDays = Set(saved.activeDays)
            self.blockingType = .fullBlock
            self.temporaryUnlocks = saved.temporaryUnlocks
            self.negativeHabitsAutoSlippedDate = saved.negativeHabitsAutoSlippedDate

            // Generate one entry per active day from legacy fields
            var entries: [BlockScheduleEntry] = []
            for day in saved.activeDays {
                entries.append(BlockScheduleEntry(
                    dayOfWeek: day,
                    startMinutes: saved.scheduleStartMinutes,
                    endMinutes: saved.scheduleEndMinutes
                ))
            }
            self.scheduleEntries = entries

            // Save as v3 immediately
            save()
        }
        // Defaults
        else {
            self.isEnabled = false
            self.scheduleStartMinutes = 9 * 60 // 9:00 AM
            self.scheduleEndMinutes = 21 * 60 // 9:00 PM
            self.activeDays = Set(1...7) // Every day
            self.blockingType = .fullBlock
            self.temporaryUnlocks = [:]
            self.negativeHabitsAutoSlippedDate = nil

            // Generate default entries
            var entries: [BlockScheduleEntry] = []
            for day in 1...7 {
                entries.append(BlockScheduleEntry(
                    dayOfWeek: day,
                    startMinutes: 9 * 60,
                    endMinutes: 21 * 60
                ))
            }
            self.scheduleEntries = entries
        }
    }

    private func save() {
        let saved = SavedBlockSettingsV3(
            isEnabled: isEnabled,
            scheduleStartMinutes: scheduleStartMinutes,
            scheduleEndMinutes: scheduleEndMinutes,
            activeDays: Array(activeDays),
            blockingType: blockingType,
            scheduleEntries: scheduleEntries,
            temporaryUnlocks: temporaryUnlocks,
            negativeHabitsAutoSlippedDate: negativeHabitsAutoSlippedDate
        )
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Self.settingsKeyV3)
        }
    }

    /// Rebuild schedule entries when legacy fields change
    private func syncEntriesToLegacy() {
        var newEntries: [BlockScheduleEntry] = []
        for day in activeDays {
            if let existing = scheduleEntries.first(where: { $0.dayOfWeek == day }) {
                // Update existing entry with new legacy times
                newEntries.append(BlockScheduleEntry(
                    id: existing.id,
                    dayOfWeek: day,
                    startMinutes: scheduleStartMinutes,
                    endMinutes: scheduleEndMinutes
                ))
            } else {
                newEntries.append(BlockScheduleEntry(
                    dayOfWeek: day,
                    startMinutes: scheduleStartMinutes,
                    endMinutes: scheduleEndMinutes
                ))
            }
        }
        scheduleEntries = newEntries
    }

    /// Sync legacy fields from current entries (used when entries change individually)
    private func syncLegacyFromEntries() {
        isSyncing = true
        activeDays = scheduledDays
        // Use the first entry's times as the legacy representative
        if let first = scheduleEntries.first {
            scheduleStartMinutes = first.startMinutes
            scheduleEndMinutes = first.endMinutes
        }
        isSyncing = false
    }

    func formatMinutes(_ minutes: Int) -> String {
        let hour = minutes / 60
        let min = minutes % 60
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, min, period)
    }
}

// MARK: - Persistence Models

/// V3 persistence format with blocking type and schedule entries
private struct SavedBlockSettingsV3: Codable {
    let isEnabled: Bool
    let scheduleStartMinutes: Int
    let scheduleEndMinutes: Int
    let activeDays: [Int]
    let blockingType: BlockingType
    let scheduleEntries: [BlockScheduleEntry]
    let temporaryUnlocks: [String: Date]
    var negativeHabitsAutoSlippedDate: Date? = nil
}

/// V2 persistence format (legacy)
private struct SavedBlockSettingsV2: Codable {
    let isEnabled: Bool
    let scheduleStartMinutes: Int
    let scheduleEndMinutes: Int
    let activeDays: [Int]
    let temporaryUnlocks: [String: Date]
    var negativeHabitsAutoSlippedDate: Date? = nil
}
