import Foundation
import SwiftData
import FamilyControls
import ManagedSettings

@Model
final class Habit {
    // CloudKit requires default values for all non-optional properties
    // Note: Enum types use raw value storage for CloudKit compatibility
    var id: UUID = UUID()
    var name: String = ""
    var habitDescription: String = ""
    private var tierRawValue: String = HabitTier.mustDo.rawValue
    private var typeRawValue: String = HabitType.positive.rawValue
    private var frequencyTypeRawValue: String = FrequencyType.daily.rawValue
    var frequencyTarget: Int = 1
    var successCriteria: String?
    var groupId: UUID?
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var isActive: Bool = true
    var createdAt: Date = Date()
    var sortOrder: Int = 0
    var isHobby: Bool = false
    @Attribute(.externalStorage) var iconImageData: Data? = nil

    /// Computed property for tier enum access
    var tier: HabitTier {
        get { HabitTier(rawValue: tierRawValue) ?? .mustDo }
        set { tierRawValue = newValue.rawValue }
    }

    /// Computed property for type enum access
    var type: HabitType {
        get { HabitType(rawValue: typeRawValue) ?? .positive }
        set { typeRawValue = newValue.rawValue }
    }

    /// Computed property for frequencyType enum access
    var frequencyType: FrequencyType {
        get { FrequencyType(rawValue: frequencyTypeRawValue) ?? .daily }
        set { frequencyTypeRawValue = newValue.rawValue }
    }

    // Options: different ways to complete this habit (e.g. ["Gym", "Swim", "Run"] for "Exercise")
    var options: [String] = []

    // Whether notes & photos are enabled for this habit (replaces isHobby concept)
    var enableNotesPhotos: Bool = false

    // Motivational micro-habit prompt for nice-to-do hobbies
    // e.g. "Put on your trainers and step outside" for Run
    var habitPrompt: String = ""

    // Schedule time slots this habit belongs to
    // Stored as raw values: "After Wake", "Morning", "During the Day", "Evening", "Before Bed"
    var scheduleTimes: [String] = []

    // Whether this negative habit should auto-slip when the user unlocks a blocked app
    // e.g. "No scrolling" — opening a blocked app means you've scrolled
    var triggersAppBlockSlip: Bool = false

    // HealthKit integration
    // Raw value stored for SwiftData compatibility
    var healthKitMetricType: String? = nil
    var healthKitTarget: Double? = nil
    var healthKitAutoComplete: Bool = true

    // Screen Time integration
    // Stores opaque ApplicationToken as Data for SwiftData compatibility
    @Attribute(.externalStorage) var screenTimeAppTokenData: Data? = nil
    var screenTimeTarget: Int? = nil  // Target minutes
    var screenTimeAutoComplete: Bool = true

    // Notification scheduling
    var notificationsEnabled: Bool = false
    var dailyNotificationMinutes: [Int] = []      // Minutes from midnight (0-1440), up to 5
    var weeklyNotificationDays: [Int] = []        // Weekday indices (1=Sun, 2=Mon, ..., 7=Sat)
    var weeklyNotificationTime: Int = 540         // Default 9:00 AM

    // Relationship to daily logs
    // Note: CloudKit requires all relationships to be optional
    @Relationship(deleteRule: .cascade, inverse: \DailyLog.habit)
    var dailyLogs: [DailyLog]?

    init(
        id: UUID = UUID(),
        name: String,
        habitDescription: String = "",
        tier: HabitTier = .mustDo,
        type: HabitType = .positive,
        frequencyType: FrequencyType = .daily,
        frequencyTarget: Int = 1,
        successCriteria: String? = nil,
        groupId: UUID? = nil,
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        isActive: Bool = true,
        createdAt: Date = Date(),
        sortOrder: Int = 0,
        isHobby: Bool = false
    ) {
        self.id = id
        self.name = name
        self.habitDescription = habitDescription
        self.tierRawValue = tier.rawValue
        self.typeRawValue = type.rawValue
        self.frequencyTypeRawValue = frequencyType.rawValue
        self.frequencyTarget = frequencyTarget
        self.successCriteria = successCriteria
        self.groupId = groupId
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.isActive = isActive
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.isHobby = isHobby
    }

    /// Returns the display text for the habit (name + criteria if applicable)
    var displayText: String {
        if let criteria = successCriteria, !criteria.isEmpty {
            return "\(name) - \(criteria)"
        }
        return name
    }

    /// Checks if this habit belongs to a group
    var isInGroup: Bool {
        groupId != nil
    }

    /// Whether this is a one-off task (not a recurring habit)
    var isTask: Bool {
        frequencyType == .once
    }

    /// Whether this habit has options (multiple ways to complete)
    var hasOptions: Bool {
        !options.isEmpty
    }

    /// Returns the frequency display name
    var frequencyDisplayName: String {
        switch frequencyType {
        case .once:
            return "Today only"
        case .daily:
            return "Daily"
        case .weekly:
            return "\(frequencyTarget)x per week"
        case .monthly:
            return "\(frequencyTarget)x per month"
        }
    }
}

// MARK: - Habit Extensions for Completion Checking

extension Habit {
    /// Gets the log for a specific date
    func log(for date: Date) -> DailyLog? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return dailyLogs?.first { calendar.isDate($0.date, inSameDayAs: startOfDay) }
    }

    /// Checks if the habit is completed for a specific date
    func isCompleted(for date: Date) -> Bool {
        guard let log = log(for: date) else { return false }
        return log.completed
    }

    /// Gets the completion value for a specific date (for measurable habits)
    func completionValue(for date: Date) -> Double? {
        guard let log = log(for: date) else { return nil }
        return log.value
    }

    /// Counts completions within a date range
    func completionCount(from startDate: Date, to endDate: Date) -> Int {
        let calendar = Calendar.current
        return (dailyLogs ?? []).filter { log in
            log.completed &&
            calendar.compare(log.date, to: startDate, toGranularity: .day) != .orderedAscending &&
            calendar.compare(log.date, to: endDate, toGranularity: .day) != .orderedDescending
        }.count
    }
}

// MARK: - HealthKit Extensions

extension Habit {
    /// Computed property to get/set HealthKit metric type enum
    var healthKitMetric: HealthKitMetricType? {
        get {
            guard let rawValue = healthKitMetricType else { return nil }
            return HealthKitMetricType(rawValue: rawValue)
        }
        set {
            healthKitMetricType = newValue?.rawValue
        }
    }

    /// Whether this habit is linked to a HealthKit metric
    var isHealthKitLinked: Bool {
        healthKitMetric != nil && healthKitTarget != nil
    }
}

// MARK: - Screen Time Extensions

extension Habit {
    /// Computed property to get/set Screen Time ApplicationToken
    var screenTimeAppToken: ApplicationToken? {
        get {
            guard let data = screenTimeAppTokenData else { return nil }
            return try? PropertyListDecoder().decode(ApplicationToken.self, from: data)
        }
        set {
            screenTimeAppTokenData = try? PropertyListEncoder().encode(newValue)
        }
    }

    /// Whether this habit is linked to a Screen Time app
    var isScreenTimeLinked: Bool {
        screenTimeAppToken != nil && screenTimeTarget != nil
    }
}

// MARK: - Criteria Display

extension Habit {
    /// Returns a display string for the habit's success criteria (manual, HealthKit, or Screen Time)
    var criteriaDisplayString: String? {
        // Check HealthKit first
        if let metric = healthKitMetric, let target = healthKitTarget {
            let formatted = formatHealthKitTarget(target, for: metric)
            return "\(formatted) \(metric.unit)"
        }

        // Check Screen Time
        if isScreenTimeLinked, let target = screenTimeTarget {
            return "\(target) min"
        }

        // Fall back to manual criteria
        if let criteria = successCriteria, !criteria.isEmpty {
            return criteria
        }

        return nil
    }

    /// Formats a HealthKit target value for display
    private func formatHealthKitTarget(_ value: Double, for metric: HealthKitMetricType) -> String {
        switch metric {
        case .steps, .flightsClimbed, .activeEnergyBurned, .appleExerciseTime, .mindfulMinutes:
            return String(format: "%.0f", value)
        case .distanceWalkingRunning, .distanceCycling, .waterIntake, .sleepHours:
            return String(format: "%.1f", value)
        }
    }
}
