import SwiftUI

/// Screen 5: Review, measure, and customise habits before creation
struct RefinementScreen: View {
    @Bindable var data: OnboardingData
    let onContinue: () -> Void
    let onGoBack: () -> Void

    @State private var appeared = false
    @State private var expandedHabitId: UUID? = nil

    private var selectedCount: Int {
        data.draftHabits.filter { $0.isSelected }.count
    }

    private var groupedHabits: [(DraftHabit.TimeOfDay, [Int])] {
        var groups: [DraftHabit.TimeOfDay: [Int]] = [:]
        for (index, habit) in data.draftHabits.enumerated() {
            groups[habit.timeOfDay, default: []].append(index)
        }

        let order: [DraftHabit.TimeOfDay] = [.afterWake, .morning, .duringTheDay, .evening, .beforeBed, .task]
        return order.compactMap { tod in
            guard let indices = groups[tod], !indices.isEmpty else { return nil }
            return (tod, indices)
        }
    }

    var body: some View {
        if data.draftHabits.isEmpty {
            emptyState
        } else {
            habitList
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("\u{1F4DD}")
                .font(.custom("PatrickHand-Regular", size: 48))

            Text("No habits yet")
                .font(.custom("PatrickHand-Regular", size: 22))
                .foregroundStyle(JournalTheme.Colors.navy)

            Text("Go back and pick some habits,\nor start fresh and add them later.")
                .font(.custom("PatrickHand-Regular", size: 15))
                .foregroundStyle(JournalTheme.Colors.completedGray)
                .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onGoBack) {
                    Text("Go back")
                        .font(.custom("PatrickHand-Regular", size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 14).fill(JournalTheme.Colors.navy))
                }

                Button(action: onContinue) {
                    Text("Start without habits")
                        .font(.custom("PatrickHand-Regular", size: 16))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Habit List

    private var habitList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Prompt
                OnboardingPromptView(
                    question: "Here\u{2019}s your day. Make it yours.",
                    subtitle: "Tap any habit to set how you\u{2019}ll measure it."
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Auto-groups banner
                if !data.draftGroups.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AUTO-GROUPED")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                            .tracking(2)

                        ForEach(data.draftGroups) { group in
                            HStack(spacing: 8) {
                                Text(group.emoji)
                                    .font(.custom("PatrickHand-Regular", size: 16))
                                Text(group.name)
                                    .font(.custom("PatrickHand-Regular", size: 14))
                                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                                Text("· do any \(group.requireCount)")
                                    .font(.custom("PatrickHand-Regular", size: 12))
                                    .foregroundStyle(JournalTheme.Colors.completedGray)
                                Spacer()
                                Text("MUST DO")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(JournalTheme.Colors.amber)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(JournalTheme.Colors.amber.opacity(0.1)))
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(JournalTheme.Colors.paperLight)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(JournalTheme.Colors.amber.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }

                        Text("These habits will be grouped together. Complete any one to satisfy the group.")
                            .font(.custom("PatrickHand-Regular", size: 12))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
                }

                // Grouped habits by time of day
                ForEach(groupedHabits, id: \.0) { timeOfDay, indices in
                    sectionView(timeOfDay: timeOfDay, indices: indices)
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button(action: onContinue) {
                    Text(selectedCount > 0 ? "Create \(selectedCount) habit\(selectedCount == 1 ? "" : "s")" : "Start without habits")
                        .font(.custom("PatrickHand-Regular", size: 16))
                        .foregroundStyle(selectedCount > 0 ? .white : JournalTheme.Colors.navy)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectedCount > 0 ? JournalTheme.Colors.navy : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    selectedCount > 0 ? Color.clear : JournalTheme.Colors.lineLight,
                                    lineWidth: 1.5
                                )
                        )
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
            .background(
                LinearGradient(
                    colors: [JournalTheme.Colors.paper.opacity(0), JournalTheme.Colors.paper],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
                .allowsHitTesting(false)
            )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                appeared = true
            }
        }
    }

    // MARK: - Section

    private func sectionView(timeOfDay: DraftHabit.TimeOfDay, indices: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack(spacing: 6) {
                Text(timeOfDay.emoji)
                    .font(.custom("PatrickHand-Regular", size: 14))
                Text(timeOfDay.rawValue.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .tracking(2)
            }
            .padding(.top, 8)

            // Habit rows
            ForEach(indices, id: \.self) { index in
                habitRow(index: index)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
    }

    // MARK: - Helpers

    /// Returns the DraftGroup this habit belongs to (if any)
    private func groupForHabit(_ habit: DraftHabit) -> DraftGroup? {
        data.draftGroups.first { $0.memberDraftIds.contains(habit.id) }
    }

    // MARK: - Habit Row

    private func habitRow(index: Int) -> some View {
        let habit = data.draftHabits[index]
        let isExpanded = expandedHabitId == habit.id
        let belongsToGroup = groupForHabit(habit)

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Checkbox
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        data.draftHabits[index].isSelected.toggle()
                    }
                    Feedback.selection()
                } label: {
                    Image(systemName: habit.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.custom("PatrickHand-Regular", size: 22))
                        .foregroundStyle(habit.isSelected ? JournalTheme.Colors.navy : JournalTheme.Colors.lineLight)
                }

                // Emoji + Name + Group badge
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(habit.emoji)
                            .font(.custom("PatrickHand-Regular", size: 15))
                        Text(habit.name)
                            .font(.custom("PatrickHand-Regular", size: 15))
                            .foregroundStyle(habit.isSelected ? JournalTheme.Colors.inkBlack : JournalTheme.Colors.completedGray)
                            .strikethrough(!habit.isSelected, color: JournalTheme.Colors.completedGray)
                    }

                    if let group = belongsToGroup {
                        HStack(spacing: 4) {
                            Text(group.emoji)
                                .font(.custom("PatrickHand-Regular", size: 10))
                            Text(group.name)
                                .font(.custom("PatrickHand-Regular", size: 11))
                                .foregroundStyle(JournalTheme.Colors.amber)
                        }
                    }
                }

                Spacer()

                // Criteria badge (tappable)
                if !habit.successCriteria.isEmpty && !isExpanded {
                    Text(habit.successCriteria)
                        .font(.custom("PatrickHand-Regular", size: 12))
                        .foregroundStyle(JournalTheme.Colors.amber)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(JournalTheme.Colors.amber.opacity(0.1))
                        )
                }

                // Frequency pill
                Text(habit.frequencyType == .once ? "One-off" : habit.frequencyType.displayName)
                    .font(.custom("PatrickHand-Regular", size: 11))
                    .foregroundStyle(habit.frequencyType == .once ? JournalTheme.Colors.teal : JournalTheme.Colors.completedGray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(habit.frequencyType == .once ? JournalTheme.Colors.teal.opacity(0.1) : JournalTheme.Colors.paperDark)
                    )

                // Tier dot
                if habit.frequencyType != .once {
                    Circle()
                        .fill(habit.tier == .mustDo ? JournalTheme.Colors.amber : JournalTheme.Colors.teal)
                        .frame(width: 6, height: 6)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard habit.isSelected else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedHabitId = isExpanded ? nil : habit.id
                }
            }

            // Expanded criteria editor
            if isExpanded && habit.isSelected {
                HStack(spacing: 8) {
                    Text("Measure:")
                        .font(.custom("PatrickHand-Regular", size: 13))
                        .foregroundStyle(JournalTheme.Colors.completedGray)

                    TextField("How will you measure this?", text: $data.draftHabits[index].successCriteria)
                        .font(.custom("PatrickHand-Regular", size: 14))
                        .foregroundStyle(JournalTheme.Colors.inkBlack)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(JournalTheme.Colors.paperLight)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(JournalTheme.Colors.amber.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.leading, 34)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isExpanded ? JournalTheme.Colors.paperLight : Color.clear)
        )
    }
}
