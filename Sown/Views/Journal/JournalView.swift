import SwiftUI

/// Tab view for browsing end-of-day reflection notes
struct JournalView: View {
    @Bindable var store: HabitStore

    var body: some View {
        NavigationStack {
            JournalContentView(store: store)
                .navigationTitle("Journal")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HelpButton(section: .journal)
                    }
                }
        }
    }
}

/// The actual content of the Journal view
struct JournalContentView: View {
    @Bindable var store: HabitStore
    @State private var selectedNoteDate: Date? = nil

    private let calendar = Calendar.current

    /// Last 30 days, newest first
    private var last30Days: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<30).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }

    private var yearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header summary
                JournalSummaryCard(store: store)

                // Daily entries
                VStack(alignment: .leading, spacing: 12) {
                    Text("RECENT ENTRIES")
                        .font(JournalTheme.Fonts.sectionHeader())
                        .foregroundStyle(JournalTheme.Colors.sectionHeader)
                        .tracking(2)

                    ForEach(last30Days, id: \.self) { date in
                        JournalDayRow(
                            date: date,
                            note: store.endOfDayNote(for: date),
                            isGoodDay: store.isGoodDay(for: date),
                            dateFormatter: dateFormatter
                        )
                        .onTapGesture {
                            Feedback.sheetOpen()
                            selectedNoteDate = date
                        }
                    }
                }

                Spacer(minLength: 100)
            }
            .padding()
        }
        .linedPaperBackground()
        .sheet(item: Binding(
            get: {
                if let date = selectedNoteDate {
                    return IdentifiableDate(date: date)
                }
                return nil
            },
            set: { selectedNoteDate = $0?.date }
        )) { item in
            EndOfDayNoteView(
                store: store,
                date: item.date,
                onDismiss: { selectedNoteDate = nil }
            )
        }
    }
}

/// Identifiable wrapper for Date (for sheet presentation)
private struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

// MARK: - Journal Summary Card

struct JournalSummaryCard: View {
    let store: HabitStore

    private var notesThisMonth: Int {
        store.recentEndOfDayNotes(days: 30).count
    }

    private var averageFulfillment: Double {
        let notes = store.recentEndOfDayNotes(days: 30)
        guard !notes.isEmpty else { return 0 }
        let sum = notes.reduce(0) { $0 + $1.fulfillmentScore }
        return Double(sum) / Double(notes.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last 30 Days")
                .font(JournalTheme.Fonts.sectionHeader())
                .foregroundStyle(JournalTheme.Colors.inkBlue)

            HStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(.custom("PatrickHand-Regular", size: 24))
                        .foregroundStyle(JournalTheme.Colors.inkBlue)

                    Text("\(notesThisMonth)")
                        .font(.custom("PatrickHand-Regular", size: 24))
                        .foregroundStyle(JournalTheme.Colors.inkBlack)

                    Text("Entries")
                        .font(JournalTheme.Fonts.habitCriteria())
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.custom("PatrickHand-Regular", size: 24))
                        .foregroundStyle(averageFulfillment >= 6 ? JournalTheme.Colors.goodDayGreenDark : JournalTheme.Colors.amber)

                    Text(averageFulfillment > 0 ? String(format: "%.1f", averageFulfillment) : "—")
                        .font(.custom("PatrickHand-Regular", size: 24))
                        .foregroundStyle(JournalTheme.Colors.inkBlack)

                    Text("Avg Score")
                        .font(JournalTheme.Fonts.habitCriteria())
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.custom("PatrickHand-Regular", size: 24))
                        .foregroundStyle(.yellow)

                    Text("\(Int(store.goodDayRate(days: 30) * 100))%")
                        .font(.custom("PatrickHand-Regular", size: 24))
                        .foregroundStyle(JournalTheme.Colors.inkBlack)

                    Text("Good Days")
                        .font(JournalTheme.Fonts.habitCriteria())
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.7))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }
}

// MARK: - Journal Day Row

struct JournalDayRow: View {
    let date: Date
    let note: EndOfDayNote?
    let isGoodDay: Bool
    let dateFormatter: DateFormatter

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Good day indicator
            Circle()
                .fill(isGoodDay ? JournalTheme.Colors.goodDayGreenDark : JournalTheme.Colors.lineLight)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isToday ? "Today" : dateFormatter.string(from: date))
                        .font(.custom("PatrickHand-Regular", size: 14))
                        .foregroundStyle(JournalTheme.Colors.inkBlack)

                    if let note = note, note.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.custom("PatrickHand-Regular", size: 9))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }
                }

                if let note = note {
                    HStack(spacing: 6) {
                        // Fulfillment score badge
                        Text("\(note.fulfillmentScore)/10")
                            .font(.custom("PatrickHand-Regular", size: 11))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(fulfillmentColor(for: note.fulfillmentScore))
                            )

                        if !note.note.isEmpty {
                            Text(note.note)
                                .font(JournalTheme.Fonts.habitCriteria())
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                                .lineLimit(1)
                        }
                    }
                } else {
                    // Can still create if editable (today or yesterday)
                    let canCreate = canCreateNote(for: date)
                    Text(canCreate ? "Tap to add reflection" : "No reflection recorded")
                        .font(JournalTheme.Fonts.habitCriteria())
                        .foregroundStyle(canCreate ? JournalTheme.Colors.inkBlue.opacity(0.5) : JournalTheme.Colors.completedGray.opacity(0.5))
                }
            }

            Spacer()

            if note != nil {
                Image(systemName: "chevron.right")
                    .font(.custom("PatrickHand-Regular", size: 12))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
            } else if canCreateNote(for: date) {
                Image(systemName: "plus")
                    .font(.custom("PatrickHand-Regular", size: 12))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.7))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }

    private func canCreateNote(for date: Date) -> Bool {
        let calendar = Calendar.current
        let noteDay = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        guard let gracePeriodEnd = calendar.date(byAdding: .day, value: 2, to: noteDay) else { return false }
        return today < gracePeriodEnd
    }

    private func fulfillmentColor(for value: Int) -> Color {
        switch value {
        case 1...3: return JournalTheme.Colors.negativeRedDark
        case 4...5: return JournalTheme.Colors.amber
        case 6...7: return JournalTheme.Colors.teal
        case 8...10: return JournalTheme.Colors.goodDayGreenDark
        default: return JournalTheme.Colors.completedGray
        }
    }
}
