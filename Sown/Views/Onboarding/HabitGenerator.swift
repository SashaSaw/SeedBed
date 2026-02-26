import Foundation

/// Converts OnboardingData selections into DraftHabit objects and auto-groups
struct HabitGenerator {

    static func generate(from data: OnboardingData) -> [DraftHabit] {
        var habits: [DraftHabit] = []

        let emojis = data.customPillEmojis

        // Map basics selections (templates + custom pills)
        habits += mapSelections(
            selected: data.selectedBasics,
            templates: HabitSuggestion.basics,
            customPills: data.customBasics,
            customPillEmojis: emojis,
            source: .basics,
            customTier: .mustDo
        )

        // Map responsibilities selections (templates + custom pills)
        habits += mapSelections(
            selected: data.selectedResponsibilities,
            templates: HabitSuggestion.responsibilities,
            customPills: data.customResponsibilities,
            customPillEmojis: emojis,
            source: .responsibilities,
            customTier: .mustDo
        )

        // Map don't-do selections (negative habits)
        habits += mapSelections(
            selected: data.selectedDontDos,
            templates: HabitSuggestion.dontDos,
            customPills: data.customDontDos,
            customPillEmojis: emojis,
            source: .dontDo,
            customTier: .mustDo,
            customType: .negative
        )

        // Map fulfilment selections (templates + custom pills)
        habits += mapSelections(
            selected: data.selectedFulfilment,
            templates: HabitSuggestion.fulfilment,
            customPills: data.customFulfilment,
            customPillEmojis: emojis,
            source: .fulfilment,
            customTier: .niceToDo
        )

        // Map one-off tasks from pills
        habits += mapTaskPills(data.todayTasks)

        // Apply schedule context (update time-specific criteria)
        applyScheduleContext(&habits, data: data)

        // Deduplicate by name
        var seen: Set<String> = []
        habits = habits.filter { habit in
            let key = habit.name.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        // Generate auto-groups and store on data
        data.draftGroups = generateAutoGroups(from: habits)

        return habits
    }

    // MARK: - Helpers

    /// Maps selected names to DraftHabits — uses templates when available, creates custom entries for user-added pills
    private static func mapSelections(
        selected: Set<String>,
        templates: [HabitSuggestion],
        customPills: [String],
        customPillEmojis: [String: String],
        source: DraftHabit.HabitSource,
        customTier: HabitTier,
        customType: HabitType = .positive
    ) -> [DraftHabit] {
        var habits: [DraftHabit] = []

        for name in selected {
            if let template = templates.first(where: { $0.name == name }) {
                // Known template — use its full config
                habits.append(draftFromTemplate(template, source: source))
            } else if customPills.contains(name) {
                // User-added custom pill — use picked emoji or sensible default
                let emoji = customPillEmojis[name] ?? (customType == .negative ? "🚫" : "✨")
                habits.append(DraftHabit(
                    name: name,
                    emoji: emoji,
                    tier: customTier,
                    type: customType,
                    frequencyType: .daily,
                    frequencyTarget: 1,
                    successCriteria: "",
                    isHobby: false,
                    enableNotesPhotos: false,
                    timeOfDay: .duringTheDay,
                    source: source
                ))
            }
        }

        return habits
    }

    private static func draftFromTemplate(_ template: HabitSuggestion, source: DraftHabit.HabitSource) -> DraftHabit {
        DraftHabit(
            name: template.name,
            emoji: template.emoji,
            tier: template.tier,
            type: template.type,
            frequencyType: template.frequencyType,
            frequencyTarget: template.frequencyTarget,
            successCriteria: template.defaultCriteria,
            isHobby: template.isHobby,
            enableNotesPhotos: template.enableNotesPhotos,
            timeOfDay: template.timeOfDay,
            source: source,
            habitPrompt: template.habitPrompt,
            triggersAppBlockSlip: template.triggersAppBlockSlip
        )
    }

    /// Creates DraftHabits from pill-based one-off tasks
    private static func mapTaskPills(_ tasks: [String]) -> [DraftHabit] {
        tasks.map { taskName in
            DraftHabit(
                name: taskName,
                emoji: "📌",
                tier: .niceToDo,
                type: .positive,
                frequencyType: .once,
                frequencyTarget: 1,
                successCriteria: "",
                isHobby: false,
                enableNotesPhotos: false,
                timeOfDay: .task,
                source: .task
            )
        }
    }

    /// Checks auto-grouping rules and creates DraftGroups for habits that qualify
    private static func generateAutoGroups(from habits: [DraftHabit]) -> [DraftGroup] {
        var groups: [DraftGroup] = []

        for rule in AutoGroupRule.rules {
            // Find habits that match this rule's member names and are selected
            let matchingHabits = habits.filter { habit in
                rule.memberNames.contains(habit.name) && habit.isSelected
            }

            // Only create a group if enough members are selected
            if matchingHabits.count >= rule.minimumMembers {
                let group = DraftGroup(
                    name: rule.groupName,
                    emoji: rule.groupEmoji,
                    memberDraftIds: matchingHabits.map { $0.id },
                    requireCount: 1
                )
                groups.append(group)
            }
        }

        return groups
    }

    private static func applyScheduleContext(_ habits: inout [DraftHabit], data: OnboardingData) {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        for i in habits.indices {
            switch habits[i].name {
            case "Wake up on time":
                habits[i].successCriteria = "by \(formatter.string(from: data.wakeUpTime))"
            case "Sleep on time":
                habits[i].successCriteria = "by \(formatter.string(from: data.bedTime))"
            default:
                break
            }
        }
    }
}
