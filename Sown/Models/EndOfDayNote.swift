import Foundation
import SwiftData

/// Stores an end-of-day reflection note with a fulfillment score.
/// Created in the evening, editable until the end of the next day (grace period),
/// then permanently locked as read-only.
@Model
final class EndOfDayNote {
    // CloudKit requires default values for all non-optional properties
    var id: UUID = UUID()
    var date: Date = Date()              // startOfDay — one note per day
    var note: String = ""
    var fulfillmentScore: Int = 5   // 1–10 scale
    var createdAt: Date = Date()
    var isLocked: Bool = false          // true after the grace period

    init(
        id: UUID = UUID(),
        date: Date,
        note: String = "",
        fulfillmentScore: Int = 5,
        createdAt: Date = Date(),
        isLocked: Bool = false
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.note = note
        self.fulfillmentScore = fulfillmentScore
        self.createdAt = createdAt
        self.isLocked = isLocked
    }
}

// MARK: - EndOfDayNote Extensions

extension EndOfDayNote {
    /// Whether this note is still editable (within grace period: until end of next day)
    var isEditable: Bool {
        guard !isLocked else { return false }
        let calendar = Calendar.current
        let noteDay = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        // Editable on the note's day and the following day
        guard let gracePeriodEnd = calendar.date(byAdding: .day, value: 2, to: noteDay) else { return false }
        return today < gracePeriodEnd
    }

    /// Short display text for the fulfillment score
    var fulfillmentEmoji: String {
        switch fulfillmentScore {
        case 1...3: return "😔"
        case 4...5: return "😐"
        case 6...7: return "🙂"
        case 8...9: return "😊"
        case 10: return "🌟"
        default: return "😐"
        }
    }

    /// Color representing the fulfillment level
    var fulfillmentColorName: String {
        switch fulfillmentScore {
        case 1...3: return "low"
        case 4...5: return "mid"
        case 6...7: return "good"
        case 8...10: return "high"
        default: return "mid"
        }
    }
}
