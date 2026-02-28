import SwiftUI
import SwiftData

/// The screen shown when a user tries to open a blocked app
/// Identity-based two-screen flow:
///   Screen 1: "How will you cast your vote?" — two choices
///   Screen 2a (controlled): Type a shame sentence to unlock
///   Screen 2b (promised): Show habits to complete
struct InterceptView: View {
    @Bindable var store: HabitStore
    let blockedAppName: String
    let blockedAppEmoji: String
    let blockedAppColor: Color
    @State private var blockSettings = BlockSettings.shared

    /// Which screen we're on
    @State private var screen: InterceptScreen = .vote

    /// Today's right choice count
    @State private var rightChoiceCount: Int = 0

    @Environment(\.dismiss) private var dismiss

    private let selectedDate = Date()
    private let lineHeight = JournalTheme.Dimensions.lineSpacing
    private let contentPadding: CGFloat = 24

    private let appGroupID = "group.com.incept5.SeedBed"
    private let rightChoiceKey = "rightChoiceCount"
    private let rightChoiceDateKey = "rightChoiceDate"

    enum InterceptScreen {
        case vote
        case controlled   // shame typing
        case countdown    // 10s countdown before unlock
        case habits       // show habits to do
    }

    // MARK: - Choice Tracking

    private func loadRightChoiceCount() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        let savedDate = defaults.string(forKey: rightChoiceDateKey) ?? ""
        let today = formatDate(Date())

        if savedDate == today {
            rightChoiceCount = defaults.integer(forKey: rightChoiceKey)
        } else {
            // Reset for new day
            rightChoiceCount = 0
            defaults.set(0, forKey: rightChoiceKey)
            defaults.set(today, forKey: rightChoiceDateKey)
        }
    }

    private func recordRightChoice() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        let today = formatDate(Date())
        defaults.set(today, forKey: rightChoiceDateKey)
        rightChoiceCount += 1
        defaults.set(rightChoiceCount, forKey: rightChoiceKey)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var body: some View {
        ZStack {
            LinedPaperBackground(lineSpacing: lineHeight)
                .ignoresSafeArea()

            switch screen {
            case .vote:
                voteScreen
            case .controlled:
                controlledScreen
            case .countdown:
                countdownScreen
            case .habits:
                habitsScreen
            }
        }
        .onAppear {
            loadRightChoiceCount()
        }
    }

    // MARK: - Screen 1: Vote

    private var voteScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            // Blocked app badge
            blockedAppBadge
                .padding(.bottom, 24)

            // Message
            Text("Every moment of weakness is a chance to choose the right path.")
                .font(.custom("PatrickHand-Regular", size: 15))
                .foregroundStyle(JournalTheme.Colors.completedGray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, contentPadding + 8)
                .padding(.bottom, 16)

            // Question
            Text("Choose wisely.")
                .font(.custom("PatrickHand-Regular", size: 28))
                .foregroundStyle(JournalTheme.Colors.inkBlack)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.bottom, 40)

            // Choice 1: Use phone (negative) - goes to countdown first
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    screen = .countdown
                }
                Feedback.selection()
            } label: {
                Text("I want to use my phone")
                    .font(.custom("PatrickHand-Regular", size: 17))
                    .foregroundStyle(JournalTheme.Colors.negativeRedDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(JournalTheme.Colors.negativeRedDark.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(JournalTheme.Colors.negativeRedDark.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, contentPadding)

            // Divider
            HStack(spacing: 12) {
                Rectangle()
                    .fill(JournalTheme.Colors.lineLight)
                    .frame(height: 1)
                Text("or")
                    .font(.custom("PatrickHand-Regular", size: 13))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                Rectangle()
                    .fill(JournalTheme.Colors.lineLight)
                    .frame(height: 1)
            }
            .padding(.horizontal, contentPadding + 20)
            .padding(.vertical, 16)

            // Choice 2: Disciplined (positive)
            Button {
                recordRightChoice()
                cacheSuggestion()
                withAnimation(.easeInOut(duration: 0.25)) {
                    screen = .habits
                }
                Feedback.selection()
            } label: {
                Text("I am a disciplined person")
                    .font(.custom("PatrickHand-Regular", size: 17))
                    .foregroundStyle(JournalTheme.Colors.successGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(JournalTheme.Colors.successGreen.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(JournalTheme.Colors.successGreen.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, contentPadding)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Screen 2a: Controlled (Shame Sentence)

    @State private var typedSentence: String = ""
    private let shameSentence = "I know this will not make me feel better but I am choosing it anyway"

    private var sentenceMatches: Bool {
        typedSentence.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            == shameSentence.lowercased()
    }

    private var controlledScreen: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    Text("Be honest with yourself first:")
                        .font(.custom("PatrickHand-Regular", size: 22))
                        .foregroundStyle(JournalTheme.Colors.inkBlack)
                        .padding(.top, 20)

                    // The sentence to copy
                    Text("\u{201C}\(shameSentence)\u{201D}")
                        .font(.custom("PatrickHand-Regular", size: 16))
                        .foregroundStyle(JournalTheme.Colors.negativeRedDark.opacity(0.8))
                        .italic()
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(JournalTheme.Colors.negativeRedDark.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(JournalTheme.Colors.negativeRedDark.opacity(0.15), lineWidth: 1)
                                )
                        )

                    // Text editor
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type it here:")
                            .font(.custom("PatrickHand-Regular", size: 14))
                            .foregroundStyle(JournalTheme.Colors.completedGray)

                        TextEditor(text: $typedSentence)
                            .font(.custom("PatrickHand-Regular", size: 16))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.7))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(sentenceMatches
                                                ? JournalTheme.Colors.successGreen.opacity(0.4)
                                                : JournalTheme.Colors.lineLight,
                                                lineWidth: 1)
                                    )
                            )
                    }

                    // Unlock button (only when sentence matches) - actually unlocks the app
                    if sentenceMatches {
                        Button {
                            // Mark all negative habits as slipped (completed = failed for negative habits)
                            markNegativeHabitsAsSlipped()
                            ScreenTimeManager.shared.grantTemporaryUnlock(minutes: 5)
                            Feedback.selection()
                            dismiss()
                        } label: {
                            Text("Continue to \(blockedAppName) (5 min)")
                                .font(.custom("PatrickHand-Regular", size: 16))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(JournalTheme.Colors.completedGray)
                                )
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Right choice encouragement
                    if rightChoiceCount > 0 {
                        Text("You made the right choice \(rightChoiceCount) time\(rightChoiceCount == 1 ? "" : "s") today. You can do it again!")
                            .font(.custom("PatrickHand-Regular", size: 14))
                            .foregroundStyle(JournalTheme.Colors.successGreen)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }

                    // Right path escape hatch - styled as a proper button
                    Button {
                        recordRightChoice()
                        cacheSuggestion()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            screen = .habits
                        }
                        Feedback.selection()
                    } label: {
                        Text("I am a disciplined person")
                            .font(.custom("PatrickHand-Regular", size: 16))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(JournalTheme.Colors.successGreen)
                            )
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, contentPadding)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: sentenceMatches)
    }

    // MARK: - Screen 2a.2: Countdown

    @State private var countdownSeconds: Int = 10
    @State private var countdownTimer: Timer? = nil

    private var countdownScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            // Countdown circle
            ZStack {
                Circle()
                    .stroke(JournalTheme.Colors.lineLight, lineWidth: 4)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(countdownSeconds) / 10.0)
                    .stroke(JournalTheme.Colors.completedGray, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: countdownSeconds)

                Text("\(countdownSeconds)")
                    .font(.custom("PatrickHand-Regular", size: 40))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                    .contentTransition(.numericText())
            }
            .padding(.bottom, 32)

            Text("Are you sure?")
                .font(.custom("PatrickHand-Regular", size: 22))
                .foregroundStyle(JournalTheme.Colors.inkBlack)
                .padding(.bottom, 8)

            Text("You still have time to change your mind.")
                .font(.custom("PatrickHand-Regular", size: 15))
                .foregroundStyle(JournalTheme.Colors.completedGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, contentPadding)
                .padding(.bottom, 24)

            // Right choice encouragement
            if rightChoiceCount > 0 {
                Text("You made the right choice \(rightChoiceCount) time\(rightChoiceCount == 1 ? "" : "s") today. You can do it again!")
                    .font(.custom("PatrickHand-Regular", size: 14))
                    .foregroundStyle(JournalTheme.Colors.successGreen)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, contentPadding)
                    .padding(.bottom, 16)
            }

            // Right path button (always visible)
            Button {
                countdownTimer?.invalidate()
                countdownTimer = nil
                recordRightChoice()
                cacheSuggestion()
                withAnimation(.easeInOut(duration: 0.25)) {
                    screen = .habits
                }
                Feedback.selection()
            } label: {
                Text("I am a disciplined person")
                    .font(.custom("PatrickHand-Regular", size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(JournalTheme.Colors.successGreen)
                    )
            }
            .padding(.horizontal, contentPadding)
            .padding(.bottom, 12)

            // Continue button (appears when countdown finishes) - goes to shame sentence
            if countdownSeconds <= 0 {
                Button {
                    countdownTimer?.invalidate()
                    countdownTimer = nil
                    withAnimation(.easeInOut(duration: 0.25)) {
                        screen = .controlled
                    }
                    Feedback.selection()
                } label: {
                    Text("Continue")
                        .font(.custom("PatrickHand-Regular", size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(JournalTheme.Colors.completedGray)
                        )
                }
                .padding(.horizontal, contentPadding)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: countdownSeconds)
        .onAppear {
            countdownSeconds = 10
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                if countdownSeconds > 0 {
                    countdownSeconds -= 1
                } else {
                    timer.invalidate()
                }
            }
        }
        .onDisappear {
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
    }

    // MARK: - Screen 2b: Habits

    @State private var showingFocusMode: Habit? = nil
    @State private var cachedSuggestion: Habit? = nil

    private var habitsScreen: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Simplified motivation banner
                simplifiedMotivationBanner

                // Single focused suggestion
                if let suggestion = cachedSuggestion {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Why don't you do this instead?")
                            .font(.custom("PatrickHand-Regular", size: 18))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)
                            .padding(.horizontal, contentPadding)

                        if suggestion.isTask {
                            InterceptTaskRow(
                                task: suggestion,
                                lineHeight: lineHeight,
                                onComplete: { store.setCompletion(for: suggestion, completed: true, on: selectedDate) }
                            )
                        } else {
                            InterceptHabitRow(
                                habit: suggestion,
                                lineHeight: lineHeight,
                                showPrompt: !suggestion.habitPrompt.isEmpty,
                                onTap: { showingFocusMode = suggestion },
                                onComplete: { store.setCompletion(for: suggestion, completed: true, on: selectedDate) }
                            )
                        }
                    }
                } else {
                    // All done state
                    HStack {
                        Text("🔥 All done! Your streak is safe.")
                            .font(.custom("PatrickHand-Regular", size: 16))
                            .foregroundStyle(JournalTheme.Colors.successGreen)
                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(JournalTheme.Colors.successGreen.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(JournalTheme.Colors.successGreen.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, contentPadding)
                }

                // Continue to Sown button
                Button {
                    Feedback.selection()
                    dismiss()
                } label: {
                    Text("Continue to Sown")
                        .font(.custom("PatrickHand-Regular", size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(JournalTheme.Colors.successGreen)
                        )
                }
                .padding(.horizontal, contentPadding)
                .padding(.top, 20)

                Spacer(minLength: 80)
            }
            .padding(.top, 16)
        }
        .sheet(item: $showingFocusMode) { habit in
            FocusModeView(store: store, habit: habit)
        }
    }

    // MARK: - Blocked App Badge

    private var blockedAppBadge: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(blockedAppColor.opacity(0.12))
                    .frame(width: 36, height: 36)

                Text(blockedAppEmoji)
                    .font(.custom("PatrickHand-Regular", size: 18))
            }

            Text("\(blockedAppName) is blocked")
                .font(.custom("PatrickHand-Regular", size: 14))
                .foregroundStyle(JournalTheme.Colors.completedGray)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(JournalTheme.Colors.paperLight)
                .overlay(
                    Capsule()
                        .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
                )
        )
    }

    // MARK: - Simplified Motivation Banner

    private var simplifiedMotivationBanner: some View {
        let streak = store.currentGoodDayStreak()

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("You chose to be the person you promised.")
                    .font(.custom("PatrickHand-Regular", size: 16))
                    .foregroundStyle(JournalTheme.Colors.successGreen)
                Spacer()
            }

            if streak > 0 {
                Text("Keep your \(streak)-day streak alive 🔥")
                    .font(.custom("PatrickHand-Regular", size: 13))
                    .foregroundStyle(JournalTheme.Colors.inkBlack.opacity(0.5))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JournalTheme.Colors.successGreen.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(JournalTheme.Colors.successGreen.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, contentPadding)
    }

    // MARK: - Suggestion Algorithm

    /// Returns the sort priority for a TimeSlot raw value (lower = earlier in day)
    private func timeSlotPriority(_ rawValue: String) -> Int {
        switch rawValue {
        case TimeSlot.afterWake.rawValue: return 0
        case TimeSlot.morning.rawValue: return 1
        case TimeSlot.duringTheDay.rawValue: return 2
        case TimeSlot.evening.rawValue: return 3
        case TimeSlot.beforeBed.rawValue: return 4
        default: return 5
        }
    }

    /// Returns the earliest time slot index for a habit (lowest = earliest in day)
    private func earliestTimeSlotPriority(for habit: Habit) -> Int {
        guard !habit.scheduleTimes.isEmpty else { return Int.max }
        return habit.scheduleTimes.map { timeSlotPriority($0) }.min() ?? Int.max
    }

    /// Sorts habits by earliest time slot, then randomly picks one from the best group
    private func pickByTimeOfDay(from habits: [Habit]) -> Habit? {
        guard !habits.isEmpty else { return nil }
        let sorted = habits.sorted { earliestTimeSlotPriority(for: $0) < earliestTimeSlotPriority(for: $1) }
        let bestPriority = earliestTimeSlotPriority(for: sorted[0])
        let bestGroup = sorted.filter { earliestTimeSlotPriority(for: $0) == bestPriority }
        return bestGroup.randomElement()
    }

    /// Computes the single highest-priority suggestion to show on the intercept habits screen
    private var suggestedItem: Habit? {
        // Tier 1: Uncompleted one-off tasks
        let tasks = store.todayVisibleTasks
        if let task = tasks.first { return task }

        // Tier 2: Uncompleted standalone must-do habits
        let undoneMustDo = store.standalonePositiveMustDoHabits.filter { !$0.isCompleted(for: selectedDate) }
        if let pick = pickByTimeOfDay(from: undoneMustDo) { return pick }

        // Tier 3: Habits from unsatisfied must-do groups
        let undoneGroups = store.mustDoGroups.filter { !$0.isSatisfied(habits: store.habits, for: selectedDate) }
        let groupHabits = undoneGroups.flatMap { store.habits(for: $0).filter { !$0.isCompleted(for: selectedDate) } }
        if let pick = pickByTimeOfDay(from: groupHabits) { return pick }

        // Tier 4: Nice-to-do habits
        let niceHabits = store.niceToDoHabits.filter { $0.isActive && !$0.isTask && !$0.isCompleted(for: selectedDate) }
        if let pick = pickByTimeOfDay(from: niceHabits) { return pick }

        return nil
    }

    /// Computes and caches the suggestion so it doesn't change on re-render
    private func cacheSuggestion() {
        cachedSuggestion = suggestedItem
    }

    /// Mark scroll-related negative habits as slipped for today (completed = true means they failed).
    /// Only targets habits with triggersAppBlockSlip = true (e.g. "No scrolling").
    /// This loses their good day and cannot be undone until the next day.
    private func markNegativeHabitsAsSlipped() {
        let scrollHabits = store.negativeHabits.filter { $0.triggersAppBlockSlip }
        guard !scrollHabits.isEmpty else { return }

        for habit in scrollHabits {
            if !habit.isCompleted(for: selectedDate) {
                store.setCompletion(for: habit, completed: true, on: selectedDate)
            }
        }
        // Lock these habits so they can't be toggled back today
        BlockSettings.shared.negativeHabitsAutoSlippedDate = Date()
    }
}

// MARK: - Intercept Habit Row

/// A tappable habit row for the intercept screen
/// Shows habitPrompt as subtitle for nice-to-do hobbies when showPrompt is true
struct InterceptHabitRow: View {
    let habit: Habit
    let lineHeight: CGFloat
    var groupName: String? = nil
    var showPrompt: Bool = false
    let onTap: () -> Void
    let onComplete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Habit emoji/icon
                RoundedRectangle(cornerRadius: 6)
                    .fill(habit.tier == .mustDo
                        ? JournalTheme.Colors.amber.opacity(0.12)
                        : JournalTheme.Colors.teal.opacity(0.12))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(habit.name.prefix(1)))
                            .font(.custom("PatrickHand-Regular", size: 14))
                            .foregroundStyle(habit.tier == .mustDo
                                ? JournalTheme.Colors.amber
                                : JournalTheme.Colors.teal)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    // Show habit prompt as primary text for hobbies, with name smaller
                    if showPrompt && !habit.habitPrompt.isEmpty {
                        Text(habit.habitPrompt)
                            .font(.custom("PatrickHand-Regular", size: 14))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)
                            .lineLimit(2)

                        Text(habit.name)
                            .font(.custom("PatrickHand-Regular", size: 11))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    } else {
                        Text(habit.name)
                            .font(JournalTheme.Fonts.habitName())
                            .foregroundStyle(JournalTheme.Colors.inkBlack)

                        if let group = groupName {
                            Text(group)
                                .font(.custom("PatrickHand-Regular", size: 11))
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                        } else if let criteria = habit.successCriteria, !criteria.isEmpty {
                            Text(criteria)
                                .font(.custom("PatrickHand-Regular", size: 11))
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.custom("PatrickHand-Regular", size: 12))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
            }
            .padding(.horizontal, 24)
            .frame(minHeight: lineHeight)
        }
    }
}

// MARK: - Intercept Task Row

/// A task row on the intercept screen (can be ticked off directly)
struct InterceptTaskRow: View {
    let task: Habit
    let lineHeight: CGFloat
    let onComplete: () -> Void

    @State private var isCompleted = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isCompleted = true
                    onComplete()
                    Feedback.completion()
                }
            } label: {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(JournalTheme.Colors.teal, lineWidth: 1.5)
                    .frame(width: 20, height: 20)
                    .overlay {
                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.custom("PatrickHand-Regular", size: 10))
                                .foregroundStyle(JournalTheme.Colors.teal)
                        }
                    }
            }

            Text(task.name)
                .font(JournalTheme.Fonts.habitName())
                .foregroundStyle(isCompleted ? JournalTheme.Colors.completedGray : JournalTheme.Colors.inkBlack)
                .strikethrough(isCompleted, color: JournalTheme.Colors.completedGray)

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(minHeight: lineHeight)
    }
}

#Preview {
    InterceptView(
        store: HabitStore(modelContext: try! ModelContainer(for: Habit.self, HabitGroup.self, DailyLog.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext),
        blockedAppName: "Instagram",
        blockedAppEmoji: "📷",
        blockedAppColor: Color(hex: "#E1306C")
    )
}
