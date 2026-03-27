import Foundation

// MARK: - Widget Data Models (duplicated from main app for target isolation)

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

// MARK: - Reader

enum WidgetDataReader {
    private static let appGroupID = "group.com.incept5.SeedBed"
    private static let fileName = "widget-data.json"

    static func read() -> WidgetHabitData {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(WidgetHabitData.self, from: data)
        else {
            return placeholder
        }
        return decoded
    }

    static var placeholder: WidgetHabitData {
        WidgetHabitData(
            streakCount: 0,
            isBlockingActive: false,
            todayTasks: [],
            mustDoTasks: [],
            niceToDoTasks: [],
            completedCount: 0,
            totalCount: 0,
            lastUpdated: Date()
        )
    }
}
