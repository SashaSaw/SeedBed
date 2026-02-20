import Foundation
import SwiftData

@Model
final class DailyLog {
    // CloudKit requires default values for all non-optional properties
    var id: UUID = UUID()
    var date: Date = Date()
    var completed: Bool = false
    var value: Double?
    var note: String?
    var photoPath: String?        // Legacy single photo (kept for backward compat)
    var photoPaths: [String] = [] // Up to 3 photos
    var selectedOption: String?
    var autoCompletedByHealthKit: Bool = false
    var autoCompletedByScreenTime: Bool = false

    // Relationship to habit
    var habit: Habit?

    init(
        id: UUID = UUID(),
        date: Date,
        completed: Bool = false,
        value: Double? = nil,
        note: String? = nil,
        photoPath: String? = nil,
        selectedOption: String? = nil,
        habit: Habit? = nil
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.completed = completed
        self.value = value
        self.note = note
        self.photoPath = photoPath
        self.selectedOption = selectedOption
        self.habit = habit
    }
}

// MARK: - DailyLog Extensions

extension DailyLog {
    /// All photo paths (merges legacy single photoPath with new photoPaths array)
    var allPhotoPaths: [String] {
        var paths = photoPaths
        // Include legacy single photo if it exists and isn't already in the array
        if let legacy = photoPath, !legacy.isEmpty, !paths.contains(legacy) {
            paths.insert(legacy, at: 0)
        }
        return paths
    }

    /// Returns true if this log has any hobby content (note or photo)
    var hasContent: Bool {
        (note != nil && !note!.isEmpty) || !allPhotoPaths.isEmpty
    }

    /// Creates or updates a log for a habit on a specific date
    static func createOrUpdate(
        for habit: Habit,
        on date: Date,
        completed: Bool,
        value: Double? = nil,
        note: String? = nil,
        photoPath: String? = nil,
        photoPaths: [String]? = nil,
        context: ModelContext
    ) -> DailyLog {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Check if log already exists
        if let existingLog = habit.log(for: date) {
            existingLog.completed = completed
            existingLog.value = value
            // Always update note and photoPath when explicitly provided
            if note != nil {
                existingLog.note = note
            }
            if photoPath != nil {
                existingLog.photoPath = photoPath
            }
            if let photoPaths = photoPaths {
                existingLog.photoPaths = photoPaths
            }
            return existingLog
        }

        // Create new log
        let newLog = DailyLog(
            date: startOfDay,
            completed: completed,
            value: value,
            note: note,
            photoPath: photoPath,
            habit: habit
        )
        if let photoPaths = photoPaths {
            newLog.photoPaths = photoPaths
        }
        context.insert(newLog)
        // Initialize dailyLogs if nil (CloudKit requires optional relationships)
        if habit.dailyLogs == nil {
            habit.dailyLogs = []
        }
        habit.dailyLogs?.append(newLog)
        return newLog
    }
}
