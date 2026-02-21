import SwiftUI

/// A single parsed criterion for the completion overlay display
private struct ParsedCriterion: Identifiable {
    let id = UUID()
    let isTime: Bool
    let targetValue: String   // e.g. "3" or "by 7:00am"
    let unit: String          // e.g. "L" or "" for time
    let label: String         // Original text for display
    var enteredValue: String = ""
    var enteredTime: Date = Date()
}

/// Overlay shown when completing a habit that has successCriteria.
/// Displays input fields for each criterion, plus Cancel/Save buttons.
struct SuccessCriteriaOverlay: View {
    let habit: Habit
    let onSave: (Double?) -> Void
    let onCancel: () -> Void

    @State private var criteria: [ParsedCriterion] = []
    @State private var appeared = false
    @FocusState private var focusedId: UUID?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background
                Color.white.opacity(0.7)
                    .onTapGesture { /* block taps */ }

                // Content card
                VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    Text("Well done!")
                        .font(.custom("PatrickHand-Regular", size: 28))
                        .foregroundStyle(JournalTheme.Colors.goodDayGreenDark)

                    Text(habit.name)
                        .font(.custom("PatrickHand-Regular", size: 18))
                        .foregroundStyle(JournalTheme.Colors.inkBlack)
                }

                // Criteria inputs
                VStack(spacing: 14) {
                    ForEach(Array(criteria.enumerated()), id: \.element.id) { index, criterion in
                        criterionRow(criterion: criterion, index: index)
                    }
                }

                // Buttons
                HStack(spacing: 16) {
                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.custom("PatrickHand-Regular", size: 16))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(JournalTheme.Colors.lineLight, lineWidth: 1)
                            )
                    }

                    Button {
                        Feedback.ding()
                        // Get the first numeric value entered for persistence
                        let primaryValue: Double? = criteria.first(where: { !$0.isTime }).flatMap {
                            Double($0.enteredValue)
                        }
                        onSave(primaryValue)
                    } label: {
                        Text("Save")
                            .font(.custom("PatrickHand-Regular", size: 16))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(JournalTheme.Colors.inkBlue)
                            )
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            )
            .padding(.horizontal, 32)
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            criteria = buildParsedCriteria(from: habit.successCriteria)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                appeared = true
            }
            // Focus first number field after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if let firstNumber = criteria.first(where: { !$0.isTime }) {
                    focusedId = firstNumber.id
                }
            }
        }
    }

    // MARK: - Criterion Row

    @ViewBuilder
    private func criterionRow(criterion: ParsedCriterion, index: Int) -> some View {
        if criterion.isTime {
            timeCriterionRow(criterion: criterion, index: index)
        } else {
            numberCriterionRow(criterion: criterion, index: index)
        }
    }

    private func numberCriterionRow(criterion: ParsedCriterion, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Recommended minimum label
            Text("Aim: \(criterion.targetValue) \(criterion.unit)")
                .font(.custom("PatrickHand-Regular", size: 12))
                .foregroundStyle(JournalTheme.Colors.completedGray)

            HStack(spacing: 10) {
                // Number input
                TextField("0", text: $criteria[index].enteredValue)
                    .font(.custom("PatrickHand-Regular", size: 20))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($focusedId, equals: criterion.id)
                    .frame(width: 80)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(JournalTheme.Colors.paperLight)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                focusedId == criterion.id
                                    ? JournalTheme.Colors.inkBlue.opacity(0.4)
                                    : JournalTheme.Colors.lineLight,
                                lineWidth: 1
                            )
                    )

                // Unit label
                Text(criterion.unit)
                    .font(.custom("PatrickHand-Regular", size: 16))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                Spacer()
            }
        }
    }

    private func timeCriterionRow(criterion: ParsedCriterion, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Target time label
            Text("Target: \(criterion.label)")
                .font(.custom("PatrickHand-Regular", size: 12))
                .foregroundStyle(JournalTheme.Colors.completedGray)

            DatePicker(
                "Time",
                selection: $criteria[index].enteredTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .colorScheme(.light)
            .frame(height: 120)
            .clipped()
        }
    }

    // MARK: - Parsing (uses shared CriteriaEditorView logic)

    /// Converts the stored criteria string into ParsedCriterion array for the overlay
    private func buildParsedCriteria(from raw: String?) -> [ParsedCriterion] {
        let entries = CriteriaEditorView.parseCriteriaString(raw)
        return entries.compactMap { entry in
            switch entry.mode {
            case .byTime:
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                let timeStr = "by " + formatter.string(from: entry.timeValue)
                return ParsedCriterion(
                    isTime: true,
                    targetValue: timeStr,
                    unit: "",
                    label: timeStr,
                    enteredTime: entry.timeValue
                )
            case .measure:
                let value = entry.value.trimmingCharacters(in: .whitespaces)
                guard !value.isEmpty else { return nil }
                let unit = entry.isCustomUnit ? entry.customUnit : entry.unit
                return ParsedCriterion(
                    isTime: false,
                    targetValue: value,
                    unit: unit,
                    label: "\(value) \(unit)",
                    enteredValue: value  // Pre-fill with goal amount
                )
            }
        }
    }
}
