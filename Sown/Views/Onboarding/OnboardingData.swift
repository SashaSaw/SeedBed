import Foundation
import SwiftUI

// MARK: - Onboarding Data (transient, not persisted)

@Observable
final class OnboardingData {
    // Screen 1: Basics (Physiological)
    var selectedBasics: Set<String> = []
    var customBasics: [String] = []          // user-added pills

    // Screen 2: Responsibilities (Safety + Belonging)
    var selectedResponsibilities: Set<String> = []
    var customResponsibilities: [String] = [] // user-added pills
    var todayTasks: [String] = []             // pill-based one-off tasks
    var selectedTasks: Set<String> = []       // selected task pills

    // Screen 3: Don't Do (negative habits to quit)
    var selectedDontDos: Set<String> = []
    var customDontDos: [String] = []

    // Screen 4: Fulfilment (Esteem + Self-Actualisation)
    var selectedFulfilment: Set<String> = []
    var customFulfilment: [String] = []      // user-added pills

    // Emoji choices for custom pills (pill name → chosen emoji)
    var customPillEmojis: [String: String] = [:]

    // Screen 4: Schedule
    var wakeUpTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    var bedTime: Date = Calendar.current.date(from: DateComponents(hour: 23, minute: 0)) ?? Date()
    var workStartTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    var workEndTime: Date = Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date()
    var hasSetWorkHours: Bool = true

    // Screen 5: Generated draft habits (populated by HabitGenerator before refinement)
    var draftHabits: [DraftHabit] = []
    var draftGroups: [DraftGroup] = []

    /// Whether the user has any selections at all
    var hasAnySelections: Bool {
        !selectedBasics.isEmpty ||
        !selectedResponsibilities.isEmpty ||
        !selectedDontDos.isEmpty ||
        !todayTasks.isEmpty ||
        !selectedFulfilment.isEmpty
    }
}

// MARK: - Draft Habit

struct DraftHabit: Identifiable {
    let id = UUID()
    var name: String
    var emoji: String
    var tier: HabitTier
    var type: HabitType
    var frequencyType: FrequencyType
    var frequencyTarget: Int
    var successCriteria: String
    var isHobby: Bool
    var enableNotesPhotos: Bool
    var isSelected: Bool = true
    var timeOfDay: TimeOfDay
    var source: HabitSource
    var habitPrompt: String = ""
    var triggersAppBlockSlip: Bool = false

    enum TimeOfDay: String, CaseIterable {
        case afterWake = "After Wake"
        case morning = "Morning"
        case duringTheDay = "During the Day"
        case evening = "Evening"
        case beforeBed = "Before Bed"
        case task = "Today's Tasks"

        var emoji: String {
            switch self {
            case .afterWake: return "🌅"
            case .morning: return "☀️"
            case .duringTheDay: return "📋"
            case .evening: return "🌙"
            case .beforeBed: return "😴"
            case .task: return "📌"
            }
        }
    }

    enum HabitSource {
        case basics
        case responsibilities
        case dontDo
        case fulfilment
        case freeText
        case task
    }
}

// MARK: - Draft Group (auto-generated from onboarding selections)

struct DraftGroup: Identifiable {
    let id = UUID()
    var name: String
    var emoji: String
    var tier: HabitTier = .mustDo   // groups are always must-do
    var memberDraftIds: [UUID]
    var requireCount: Int = 1       // "complete any 1 of N"
}

// MARK: - Auto-Grouping Rules

struct AutoGroupRule {
    let groupName: String
    let groupEmoji: String
    let memberNames: Set<String>
    let minimumMembers: Int

    static let rules: [AutoGroupRule] = [
        AutoGroupRule(
            groupName: "Be Mindful",
            groupEmoji: "🧘",
            memberNames: ["Journal", "Meditate"],
            minimumMembers: 2
        ),
        AutoGroupRule(
            groupName: "Exercise",
            groupEmoji: "💪",
            memberNames: ["Gym", "Run", "Cycle"],
            minimumMembers: 2
        ),
        AutoGroupRule(
            groupName: "Be Creative",
            groupEmoji: "🎨",
            memberNames: ["Draw or paint", "Play music", "Write", "Craft", "Photography", "Cook something new"],
            minimumMembers: 2
        ),
    ]
}

// MARK: - Suggestion Templates

struct HabitSuggestion {
    let emoji: String
    let name: String
    let defaultCriteria: String
    let frequencyType: FrequencyType
    let frequencyTarget: Int
    let tier: HabitTier
    let type: HabitType
    let isHobby: Bool
    let enableNotesPhotos: Bool
    let timeOfDay: DraftHabit.TimeOfDay
    let habitPrompt: String
    let triggersAppBlockSlip: Bool

    init(
        emoji: String,
        name: String,
        defaultCriteria: String = "",
        frequencyType: FrequencyType = .daily,
        frequencyTarget: Int = 1,
        tier: HabitTier = .mustDo,
        type: HabitType = .positive,
        isHobby: Bool = false,
        enableNotesPhotos: Bool = false,
        timeOfDay: DraftHabit.TimeOfDay = .duringTheDay,
        habitPrompt: String = "",
        triggersAppBlockSlip: Bool = false
    ) {
        self.emoji = emoji
        self.name = name
        self.defaultCriteria = defaultCriteria
        self.frequencyType = frequencyType
        self.frequencyTarget = frequencyTarget
        self.tier = tier
        self.type = type
        self.isHobby = isHobby
        self.enableNotesPhotos = enableNotesPhotos
        self.timeOfDay = timeOfDay
        self.habitPrompt = habitPrompt
        self.triggersAppBlockSlip = triggersAppBlockSlip
    }
}

// MARK: - Suggestion Lists

extension HabitSuggestion {

    static let basics: [HabitSuggestion] = [
        HabitSuggestion(emoji: "💧", name: "Drink enough water", defaultCriteria: "2-3L", timeOfDay: .duringTheDay),
        HabitSuggestion(emoji: "😴", name: "Sleep on time", defaultCriteria: "by 11pm", timeOfDay: .beforeBed),
        HabitSuggestion(emoji: "🍳", name: "Eat proper meals", defaultCriteria: "3 meals", timeOfDay: .duringTheDay),
        HabitSuggestion(emoji: "💊", name: "Take vitamins", timeOfDay: .afterWake),
        HabitSuggestion(emoji: "🚶", name: "Move your body", defaultCriteria: "30 min", timeOfDay: .duringTheDay),
        HabitSuggestion(emoji: "🌅", name: "Wake up on time", defaultCriteria: "by 7am", timeOfDay: .afterWake),
    ]

    static let responsibilities: [HabitSuggestion] = [
        HabitSuggestion(emoji: "🛏️", name: "Make bed", timeOfDay: .afterWake),
        HabitSuggestion(emoji: "🧹", name: "Tidy up", defaultCriteria: "15 min", timeOfDay: .evening),
        HabitSuggestion(emoji: "📞", name: "Call family", frequencyType: .weekly, timeOfDay: .evening),
        HabitSuggestion(emoji: "🦷", name: "Brush & floss", timeOfDay: .afterWake),
        HabitSuggestion(emoji: "🐕", name: "Walk the dog", timeOfDay: .afterWake),
        HabitSuggestion(emoji: "💰", name: "Review budget", frequencyType: .monthly, timeOfDay: .evening),
        HabitSuggestion(emoji: "🌙", name: "Wind-down routine", defaultCriteria: "30 min", tier: .niceToDo, timeOfDay: .beforeBed),
    ]

    static let dontDos: [HabitSuggestion] = [
        HabitSuggestion(emoji: "📵", name: "No scrolling", type: .negative, timeOfDay: .duringTheDay, triggersAppBlockSlip: true),
        HabitSuggestion(emoji: "🍔", name: "No junk food", type: .negative, timeOfDay: .duringTheDay),
        HabitSuggestion(emoji: "🚭", name: "No smoking", type: .negative, timeOfDay: .duringTheDay),
        HabitSuggestion(emoji: "🚫", name: "No alcohol", type: .negative, timeOfDay: .evening),
        HabitSuggestion(emoji: "🌙", name: "No late-night snacking", type: .negative, timeOfDay: .beforeBed),
    ]

    static let fulfilment: [HabitSuggestion] = [
        HabitSuggestion(emoji: "📖", name: "Read", defaultCriteria: "30 min", tier: .niceToDo, timeOfDay: .beforeBed,
                        habitPrompt: "Pick up your book and read one page"),
        HabitSuggestion(emoji: "🧘", name: "Meditate", defaultCriteria: "10 min", tier: .niceToDo, timeOfDay: .afterWake,
                        habitPrompt: "Sit down, close your eyes, take one breath"),
        HabitSuggestion(emoji: "✏️", name: "Journal", defaultCriteria: "15 min", tier: .niceToDo, timeOfDay: .beforeBed,
                        habitPrompt: "Open your journal and write today's date"),
        HabitSuggestion(emoji: "🎸", name: "Play music", defaultCriteria: "20 min", tier: .niceToDo, isHobby: true, enableNotesPhotos: true, timeOfDay: .evening,
                        habitPrompt: "Pick up the guitar and strum a few strings"),
        HabitSuggestion(emoji: "🎨", name: "Draw or paint", tier: .niceToDo, isHobby: true, enableNotesPhotos: true, timeOfDay: .evening,
                        habitPrompt: "Open the sketchbook and draw one line"),
        HabitSuggestion(emoji: "📷", name: "Photography", frequencyType: .weekly, tier: .niceToDo, isHobby: true, enableNotesPhotos: true, timeOfDay: .duringTheDay,
                        habitPrompt: "Grab your camera and take one photo"),
        HabitSuggestion(emoji: "🗣️", name: "Practice a language", defaultCriteria: "15 min", tier: .niceToDo, timeOfDay: .morning,
                        habitPrompt: "Open the app and do one lesson"),
        HabitSuggestion(emoji: "📝", name: "Write", defaultCriteria: "30 min", tier: .niceToDo, isHobby: true, enableNotesPhotos: true, timeOfDay: .evening,
                        habitPrompt: "Open a blank page and write one sentence"),
        HabitSuggestion(emoji: "🏃", name: "Run", defaultCriteria: "5km", frequencyType: .weekly, frequencyTarget: 3, tier: .niceToDo, timeOfDay: .duringTheDay,
                        habitPrompt: "Put on your trainers and step outside"),
        HabitSuggestion(emoji: "💪", name: "Gym", defaultCriteria: "30 min", tier: .niceToDo, isHobby: true, enableNotesPhotos: true, timeOfDay: .duringTheDay,
                        habitPrompt: "Take a water bottle and walk to the gym"),
        HabitSuggestion(emoji: "🚴", name: "Cycle", defaultCriteria: "30 min", frequencyType: .weekly, frequencyTarget: 3, tier: .niceToDo, isHobby: true, enableNotesPhotos: true, timeOfDay: .duringTheDay,
                        habitPrompt: "Pump the tyres and get on the saddle"),
        HabitSuggestion(emoji: "🍳", name: "Cook something new", frequencyType: .weekly, tier: .niceToDo, isHobby: true, enableNotesPhotos: true, timeOfDay: .evening,
                        habitPrompt: "Pick a recipe and lay out the ingredients"),
        HabitSuggestion(emoji: "🧶", name: "Craft", frequencyType: .weekly, tier: .niceToDo, isHobby: true, enableNotesPhotos: true, timeOfDay: .evening,
                        habitPrompt: "Get your materials out on the table"),
    ]
}
