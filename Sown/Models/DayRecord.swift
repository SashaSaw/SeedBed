import Foundation
import SwiftData

/// Tracks whether a day was a "good day" (all must-dos completed, no negative slips).
/// Once locked at midnight, a good day cannot be undone by adding new habits.
@Model
final class DayRecord {
    // CloudKit requires default values for all non-optional properties
    var id: UUID = UUID()
    var date: Date = Date()          // startOfDay
    var isGoodDay: Bool = false
    var lockedAt: Date?     // when good day was locked in (midnight)

    init(
        id: UUID = UUID(),
        date: Date,
        isGoodDay: Bool = false,
        lockedAt: Date? = nil
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.isGoodDay = isGoodDay
        self.lockedAt = lockedAt
    }
}
