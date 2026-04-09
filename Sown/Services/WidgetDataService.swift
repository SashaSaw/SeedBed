import Foundation
import WidgetKit

// MARK: - Widget Data Models

struct WidgetHabitData: Codable {
    let streakCount: Int
    let isBlockingActive: Bool
    let todayTasks: [WidgetTask]
    let mustDoTasks: [WidgetTask]
    let niceToDoTasks: [WidgetTask]
    let completedCount: Int
    let totalCount: Int
    let lastUpdated: Date
}

struct WidgetTask: Codable, Identifiable {
    let id: UUID
    let name: String
    let isCompleted: Bool
}

// MARK: - Widget Data Service

enum WidgetDataService {
    private static let appGroupID = "group.com.incept5.SeedBed"
    private static let fileName = "widget-data.json"

    static var sharedFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    static func updateWidgetData(from store: HabitStore) {
        let today = Calendar.current.startOfDay(for: Date())

        // One-off today tasks (visible incomplete + completed today)
        let todayTaskItems = (store.todayVisibleTasks + store.todayCompletedTasks).map { habit in
            WidgetTask(id: habit.id, name: habit.name, isCompleted: habit.isCompleted(for: today))
        }

        // Must-do: standalone habits (not in groups) + groups as single items
        let standaloneMustDo = store.standalonePositiveMustDoHabits.map { habit in
            WidgetTask(id: habit.id, name: habit.name, isCompleted: habit.isCompleted(for: today))
        }
        let mustDoGroupTasks = store.mustDoGroups.map { group in
            let completed = group.completedCount(habits: store.habits, for: today)
            let name = "\(group.name) (\(completed) of \(group.requireCount))"
            return WidgetTask(id: group.id, name: name, isCompleted: group.isSatisfied(habits: store.habits, for: today))
        }
        let mustDo = standaloneMustDo + mustDoGroupTasks

        // Nice-to-do: standalone habits (not in groups) + groups as single items
        let standaloneNiceToDo = store.standalonePositiveNiceToDoHabits.map { habit in
            WidgetTask(id: habit.id, name: habit.name, isCompleted: habit.isCompleted(for: today))
        }
        let niceToDoGroupTasks = store.niceToDoGroups.map { group in
            let completed = group.completedCount(habits: store.habits, for: today)
            let name = "\(group.name) (\(completed) of \(group.requireCount))"
            return WidgetTask(id: group.id, name: name, isCompleted: group.isSatisfied(habits: store.habits, for: today))
        }
        let niceToDo = standaloneNiceToDo + niceToDoGroupTasks

        let allItems = todayTaskItems + mustDo + niceToDo
        let data = WidgetHabitData(
            streakCount: store.currentGoodDayStreak(),
            isBlockingActive: BlockSettings.shared.isEnabled,
            todayTasks: todayTaskItems,
            mustDoTasks: mustDo,
            niceToDoTasks: niceToDo,
            completedCount: allItems.filter(\.isCompleted).count,
            totalCount: allItems.count,
            lastUpdated: Date()
        )

        guard let url = sharedFileURL else { return }

        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url, options: .atomic)
        } catch {
            print("Failed to write widget data: \(error)")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}
