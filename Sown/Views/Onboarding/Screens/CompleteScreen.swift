import SwiftUI

/// Screen 6: Pledge + Create habits + Celebration
struct CompleteScreen: View {
    @Bindable var data: OnboardingData
    let store: HabitStore
    let onFinish: () -> Void

    @State private var showPledge = true
    @State private var pledgeAppeared = false
    @State private var habitsCreated = false
    @State private var visibleCount = 0
    @State private var showCheckmark = false
    @State private var showFinalButton = false

    private var selectedHabits: [DraftHabit] {
        data.draftHabits.filter { $0.isSelected }
    }

    var body: some View {
        if showPledge {
            pledgeView
        } else {
            celebrationView
        }
    }

    // MARK: - Pledge View

    private var pledgeView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                // Small decorative mark
                Text("\u{270F}\u{FE0F}")
                    .font(.custom("PatrickHand-Regular", size: 40))
                    .opacity(pledgeAppeared ? 1 : 0)
                    .offset(y: pledgeAppeared ? 0 : 10)

                // Intro
                Text("Before you start, one small promise.")
                    .font(.custom("PatrickHand-Regular", size: 15))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .opacity(pledgeAppeared ? 1 : 0)
                    .offset(y: pledgeAppeared ? 0 : 10)

                // The pledge
                VStack(spacing: 16) {
                    Text("\u{201C}I\u{2019}ll be honest with myself.\u{201D}")
                        .font(.custom("PatrickHand-Regular", size: 24))
                        .foregroundStyle(JournalTheme.Colors.navy)
                        .multilineTextAlignment(.center)

                    Text("When I cross something off, it means I actually did it. No half-credits. No \u{201C}close enough.\u{201D}\n\nThis list only works if I trust it \u{2014} and I can only trust it if I\u{2019}m truthful.\n\nSome days I\u{2019}ll get everything done. Some days I won\u{2019}t. Both are fine. What matters is that when I look at my streaks, they\u{2019}re real.")
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(JournalTheme.Colors.inkBlack.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 8)
                .opacity(pledgeAppeared ? 1 : 0)
                .offset(y: pledgeAppeared ? 0 : 10)
            }
            .padding(.horizontal, 32)

            Spacer()

            // Pledge button
            Button {
                Feedback.success()
                withAnimation(.easeInOut(duration: 0.4)) {
                    showPledge = false
                }
                // Start celebration immediately, create habits concurrently
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    startCelebrationSequence()
                    Task {
                        createHabits()
                    }
                }
            } label: {
                Text("I promise")
                    .font(.custom("PatrickHand-Regular", size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(JournalTheme.Colors.navy)
                    )
            }
            .opacity(pledgeAppeared ? 1 : 0)
            .offset(y: pledgeAppeared ? 0 : 20)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) { pledgeAppeared = true }
        }
    }

    // MARK: - Celebration View

    private var celebrationView: some View {
        VStack(spacing: 0) {
            Spacer()

            if selectedHabits.isEmpty {
                // No habits — simple message
                VStack(spacing: 16) {
                    HandDrawnCheckmark(size: 60, color: JournalTheme.Colors.successGreen, animated: true)

                    Text("You\u{2019}re all set.")
                        .font(.custom("PatrickHand-Regular", size: 26))
                        .foregroundStyle(JournalTheme.Colors.navy)

                    Text("Add habits anytime from the app.")
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }
            } else {
                // Habit creation animation
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(selectedHabits.enumerated()), id: \.element.id) { index, habit in
                        HStack(spacing: 10) {
                            Text(habit.emoji)
                                .font(.custom("PatrickHand-Regular", size: 14))

                            Text(habit.name)
                                .font(.custom("PatrickHand-Regular", size: 15))
                                .foregroundStyle(JournalTheme.Colors.inkBlack)

                            if !habit.successCriteria.isEmpty {
                                Text("\u{00B7} \(habit.successCriteria)")
                                    .font(.custom("PatrickHand-Regular", size: 13))
                                    .foregroundStyle(JournalTheme.Colors.completedGray)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .opacity(visibleCount > index ? 1 : 0)
                        .offset(x: visibleCount > index ? 0 : -15)
                    }
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 32)

                // Checkmark + completion message
                if showCheckmark {
                    VStack(spacing: 12) {
                        HandDrawnCheckmark(size: 50, color: JournalTheme.Colors.successGreen, animated: true)

                        Text("You\u{2019}re all set.")
                            .font(.custom("PatrickHand-Regular", size: 26))
                            .foregroundStyle(JournalTheme.Colors.navy)

                        Text("\(selectedHabits.count) habit\(selectedHabits.count == 1 ? "" : "s") ready to track")
                            .font(.custom("PatrickHand-Regular", size: 15))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }

            Spacer()

            // Start button
            if showFinalButton {
                Button(action: onFinish) {
                    Text("Start my day")
                        .font(.custom("PatrickHand-Regular", size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(JournalTheme.Colors.successGreen)
                        )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    // MARK: - Habit Creation

    private func createHabits() {
        // Batch-create all habits in one save+fetch cycle
        let drafts = selectedHabits.map { draft in
            let habitName = draft.emoji.isEmpty ? draft.name : "\(draft.emoji) \(draft.name)"
            return (
                name: habitName,
                tier: draft.tier,
                type: draft.type,
                frequencyType: draft.frequencyType,
                frequencyTarget: draft.frequencyTarget,
                successCriteria: draft.successCriteria.isEmpty ? nil as String? : draft.successCriteria,
                isHobby: draft.isHobby,
                enableNotesPhotos: draft.enableNotesPhotos,
                habitPrompt: draft.habitPrompt,
                scheduleTimes: [draft.timeOfDay.rawValue],
                triggersAppBlockSlip: draft.triggersAppBlockSlip
            )
        }

        let createdHabits = store.addHabitsBatch(drafts)

        // Map draft IDs to created habits
        var draftToHabit: [UUID: Habit] = [:]
        for (index, draft) in selectedHabits.enumerated() {
            if index < createdHabits.count {
                draftToHabit[draft.id] = createdHabits[index]
            }
        }

        // Batch-create groups
        let groupDrafts: [(name: String, tier: HabitTier, requireCount: Int, habitIds: [UUID])] = data.draftGroups.compactMap { draftGroup in
            let memberHabitIds = draftGroup.memberDraftIds.compactMap { draftId -> UUID? in
                guard let habit = draftToHabit[draftId] else { return nil }
                return habit.id
            }
            guard memberHabitIds.count >= 2 else { return nil }
            return (
                name: "\(draftGroup.emoji) \(draftGroup.name)",
                tier: HabitTier.mustDo,
                requireCount: draftGroup.requireCount,
                habitIds: memberHabitIds
            )
        }

        if !groupDrafts.isEmpty {
            store.addGroupsBatch(groupDrafts)
        }

        // Save wake/bed times via UserSchedule singleton
        UserSchedule.shared.updateFromOnboarding(wakeTime: data.wakeUpTime, bedTime: data.bedTime)

        // Schedule notifications based on habit time slots
        store.refreshNotifications()

        habitsCreated = true
    }

    // MARK: - Animation Sequence

    private func startCelebrationSequence() {
        guard !selectedHabits.isEmpty else {
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) { showCheckmark = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.8)) { showFinalButton = true }
            return
        }

        // Stagger habit names appearing
        for i in 0..<selectedHabits.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 * Double(i)) {
                withAnimation(.easeOut(duration: 0.3)) {
                    visibleCount = i + 1
                }
                if i < selectedHabits.count {
                    Feedback.selection()
                }
            }
        }

        // Show checkmark after all habits
        let totalDelay = 0.15 * Double(selectedHabits.count) + 0.4
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showCheckmark = true
            }
            Feedback.success()
        }

        // Show button
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay + 0.6) {
            withAnimation(.easeOut(duration: 0.4)) {
                showFinalButton = true
            }
        }
    }
}
