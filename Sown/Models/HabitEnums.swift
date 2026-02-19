import Foundation

/// Sort mode for TodayView - determines how habits are organized
enum TodaySortMode: String, Codable, CaseIterable, Sendable {
    case byType = "by_type"
    case byTimeOfDay = "by_time_of_day"

    var displayName: String {
        switch self {
        case .byType: return "By Type"
        case .byTimeOfDay: return "By Time"
        }
    }
}

/// Time slots for scheduling habits throughout the day
enum TimeSlot: String, CaseIterable, Sendable {
    case afterWake = "After Wake"
    case morning = "Morning"
    case duringTheDay = "During the Day"
    case evening = "Evening"
    case beforeBed = "Before Bed"

    var emoji: String {
        switch self {
        case .afterWake: return "🌅"
        case .morning: return "☀️"
        case .duringTheDay: return "📋"
        case .evening: return "🌆"
        case .beforeBed: return "🌙"
        }
    }

    var displayName: String {
        switch self {
        case .afterWake: return "AFTER WAKE"
        case .morning: return "MORNING"
        case .duringTheDay: return "DAYTIME"
        case .evening: return "EVENING"
        case .beforeBed: return "BEFORE BED"
        }
    }
}

/// Represents the tier/priority level of a habit
enum HabitTier: String, Codable, CaseIterable, Sendable {
    case mustDo = "must_do"
    case niceToDo = "nice_to_do"

    var displayName: String {
        switch self {
        case .mustDo: return "Must Do"
        case .niceToDo: return "Nice To Do"
        }
    }
}

/// Represents whether a habit is positive (to do) or negative (to avoid)
enum HabitType: String, Codable, CaseIterable, Sendable {
    case positive
    case negative

    var displayName: String {
        switch self {
        case .positive: return "Build a habit"
        case .negative: return "Quit a habit"
        }
    }

    var description: String {
        switch self {
        case .positive: return "Something you want to do"
        case .negative: return "Something you want to stop"
        }
    }
}

/// Represents the frequency type without associated values (for SwiftData compatibility)
enum FrequencyType: String, Codable, CaseIterable, Sendable {
    case once
    case daily
    case weekly
    case monthly

    var displayName: String {
        switch self {
        case .once: return "Just today"
        case .daily: return "Every day"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }

    /// Whether this frequency type represents a one-off task
    var isTask: Bool {
        self == .once
    }

    /// Cases shown in the add flow frequency picker (all cases)
    static var addFlowCases: [FrequencyType] {
        [.once, .daily, .weekly, .monthly]
    }

    /// Cases for recurring habits only (excludes once)
    static var recurringCases: [FrequencyType] {
        [.daily, .weekly, .monthly]
    }
}

/// Represents the type of HealthKit metric that can be linked to a habit
enum HealthKitMetricType: String, Codable, CaseIterable, Sendable {
    case steps
    case distanceWalkingRunning
    case distanceCycling
    case activeEnergyBurned
    case appleExerciseTime
    case flightsClimbed
    case mindfulMinutes
    case sleepHours
    case waterIntake

    var displayName: String {
        switch self {
        case .steps: return "Steps"
        case .distanceWalkingRunning: return "Walking + Running Distance"
        case .distanceCycling: return "Cycling Distance"
        case .activeEnergyBurned: return "Active Calories"
        case .appleExerciseTime: return "Exercise Minutes"
        case .flightsClimbed: return "Flights Climbed"
        case .mindfulMinutes: return "Mindful Minutes"
        case .sleepHours: return "Sleep Hours"
        case .waterIntake: return "Water Intake"
        }
    }

    var unit: String {
        switch self {
        case .steps: return "steps"
        case .distanceWalkingRunning: return "km"
        case .distanceCycling: return "km"
        case .activeEnergyBurned: return "kcal"
        case .appleExerciseTime: return "min"
        case .flightsClimbed: return "flights"
        case .mindfulMinutes: return "min"
        case .sleepHours: return "hrs"
        case .waterIntake: return "L"
        }
    }

    var icon: String {
        switch self {
        case .steps: return "figure.walk"
        case .distanceWalkingRunning: return "figure.run"
        case .distanceCycling: return "bicycle"
        case .activeEnergyBurned: return "flame.fill"
        case .appleExerciseTime: return "figure.strengthtraining.traditional"
        case .flightsClimbed: return "figure.stairs"
        case .mindfulMinutes: return "brain.head.profile"
        case .sleepHours: return "bed.double.fill"
        case .waterIntake: return "drop.fill"
        }
    }

    var defaultTarget: Double {
        switch self {
        case .steps: return 10000
        case .distanceWalkingRunning: return 5.0
        case .distanceCycling: return 10.0
        case .activeEnergyBurned: return 500
        case .appleExerciseTime: return 30
        case .flightsClimbed: return 10
        case .mindfulMinutes: return 10
        case .sleepHours: return 8
        case .waterIntake: return 2.5
        }
    }
}
