import Foundation
import SwiftData

@Model
final class HabitGroup {
    // CloudKit requires default values for all non-optional properties
    // Note: Enum types use raw value storage for CloudKit compatibility
    var id: UUID = UUID()
    var name: String = ""
    private var tierRawValue: String = HabitTier.mustDo.rawValue
    var requireCount: Int = 1
    var habitIds: [UUID] = []
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    /// Computed property for tier enum access
    var tier: HabitTier {
        get { HabitTier(rawValue: tierRawValue) ?? .mustDo }
        set { tierRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        tier: HabitTier = .mustDo,
        requireCount: Int = 1,
        habitIds: [UUID] = [],
        sortOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.tierRawValue = tier.rawValue
        self.requireCount = requireCount
        self.habitIds = habitIds
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    /// Display text showing requirement (e.g., "1 of 2")
    var requirementText: String {
        "(\(requireCount) of \(habitIds.count))"
    }
}

// MARK: - HabitGroup Extensions

extension HabitGroup {
    /// Checks if the group requirement is satisfied for a given date
    func isSatisfied(habits: [Habit], for date: Date) -> Bool {
        let groupHabits = habits.filter { habitIds.contains($0.id) }
        let completedCount = groupHabits.filter { $0.isCompleted(for: date) }.count
        return completedCount >= requireCount
    }

    /// Returns the number of completed habits in this group for a given date
    func completedCount(habits: [Habit], for date: Date) -> Int {
        let groupHabits = habits.filter { habitIds.contains($0.id) }
        return groupHabits.filter { $0.isCompleted(for: date) }.count
    }

    /// Returns the habits that belong to this group
    func getHabits(from allHabits: [Habit]) -> [Habit] {
        allHabits.filter { habitIds.contains($0.id) }
    }
}
