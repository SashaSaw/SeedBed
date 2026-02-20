import SwiftUI
import SwiftData

/// A single habit row in the Today View
struct HabitRowView: View {
    let habit: Habit
    let isCompleted: Bool
    let isIndented: Bool
    let onToggle: () -> Void
    var onLongPress: (() -> Void)?

    @State private var showStrikethrough = false
    @State private var strikethroughProgress: CGFloat = 0
    @State private var strikethroughWidth: CGFloat = 0
    @State private var healthKitManager = HealthKitManager.shared

    init(
        habit: Habit,
        isCompleted: Bool,
        isIndented: Bool = false,
        onToggle: @escaping () -> Void,
        onLongPress: (() -> Void)? = nil
    ) {
        self.habit = habit
        self.isCompleted = isCompleted
        self.isIndented = isIndented
        self.onToggle = onToggle
        self.onLongPress = onLongPress
        self._showStrikethrough = State(initialValue: isCompleted)
        self._strikethroughProgress = State(initialValue: isCompleted ? 1.0 : 0.0)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Indent for grouped habits
            if isIndented {
                HStack(spacing: 4) {
                    Text("├─")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(JournalTheme.Colors.lineLight)
                }
                .frame(width: 24)
            }

            // Completion indicator
            CompletionIndicator(
                isCompleted: isCompleted,
                habitType: habit.type,
                animated: true
            )
            .frame(width: 24, height: 24)

            // Habit name and criteria
            VStack(alignment: .leading, spacing: 2) {
                GeometryReader { geometry in
                    HStack(spacing: 4) {
                        Text(habit.name)
                            .font(JournalTheme.Fonts.habitName())
                            .foregroundStyle(isCompleted ? JournalTheme.Colors.completedGray : JournalTheme.Colors.inkBlack)

                        if let criteria = habit.criteriaDisplayString {
                            Text("(\(criteria))")
                                .font(JournalTheme.Fonts.habitCriteria())
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                        }

                        // HealthKit progress badge
                        if habit.isHealthKitLinked, let metric = habit.healthKitMetric {
                            HealthKitProgressBadge(
                                metric: metric,
                                target: habit.healthKitTarget ?? 0,
                                currentValue: healthKitManager.currentValues[metric] ?? 0
                            )
                        }

                        // Screen Time progress badge
                        if habit.isScreenTimeLinked, let targetMinutes = habit.screenTimeTarget {
                            ScreenTimeProgressBadge(targetMinutes: targetMinutes)
                        }

                        Spacer()
                    }
                    .overlay(alignment: .leading) {
                        if showStrikethrough {
                            StrikethroughLine(
                                width: geometry.size.width * 0.85,
                                color: habit.type == .positive
                                    ? JournalTheme.Colors.inkBlue
                                    : JournalTheme.Colors.negativeRedDark,
                                progress: $strikethroughProgress
                            )
                            .offset(y: 2)
                        }
                    }
                    .onAppear {
                        strikethroughWidth = geometry.size.width * 0.85
                    }
                }
                .frame(height: 24)

                // Streak indicator
                if habit.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.custom("PatrickHand-Regular", size: 10))
                            .foregroundStyle(.orange)
                        Text("\(habit.currentStreak) day streak")
                            .font(JournalTheme.Fonts.streakCount())
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, isIndented ? 8 : 16)
        .contentShape(Rectangle())
        .onTapGesture {
            Feedback.completion()
            let newState = !isCompleted
            showStrikethrough = newState
            withAnimation(JournalTheme.Animations.completion) {
                strikethroughProgress = newState ? 1.0 : 0.0
            }
            onToggle()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            Feedback.longPress()
            onLongPress?()
        }
        .onChange(of: isCompleted) { oldValue, newValue in
            showStrikethrough = newValue
            withAnimation(JournalTheme.Animations.completion) {
                strikethroughProgress = newValue ? 1.0 : 0.0
            }
        }
    }
}

/// A habit group header with its child habits
struct HabitGroupRowView: View {
    let group: HabitGroup
    let habits: [Habit]
    let completedCount: Int
    let isSatisfied: Bool
    let onToggleHabit: (Habit) -> Void
    let isCompletedForHabit: (Habit) -> Bool

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            HStack(spacing: 12) {
                // Satisfaction indicator
                if isSatisfied {
                    HandDrawnCheckmark(size: 22, animated: true)
                } else {
                    EmptyCheckbox(size: 22)
                }

                Text(group.name)
                    .font(JournalTheme.Fonts.habitName())
                    .foregroundStyle(isSatisfied ? JournalTheme.Colors.completedGray : JournalTheme.Colors.inkBlack)

                Text("(\(completedCount) of \(group.requireCount))")
                    .font(JournalTheme.Fonts.habitCriteria())
                    .foregroundStyle(JournalTheme.Colors.completedGray)

                Spacer()

                // Expand/collapse button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.custom("PatrickHand-Regular", size: 12))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())

            // Child habits
            if isExpanded {
                ForEach(habits) { habit in
                    HabitRowView(
                        habit: habit,
                        isCompleted: isCompletedForHabit(habit),
                        isIndented: true,
                        onToggle: { onToggleHabit(habit) }
                    )
                    .padding(.leading, 16)
                }
            }
        }
    }
}

/// Progress badge showing HealthKit metric progress
struct HealthKitProgressBadge: View {
    let metric: HealthKitMetricType
    let target: Double
    let currentValue: Double

    private var isComplete: Bool {
        currentValue >= target
    }

    private var progressText: String {
        let current = HealthKitManager.shared.formatValue(currentValue, for: metric)
        let targetFormatted = HealthKitManager.shared.formatValue(target, for: metric)
        return "\(current)/\(targetFormatted)"
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: metric.icon)
                .font(.system(size: 9))
            Text(progressText)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(isComplete ? JournalTheme.Colors.successGreen : JournalTheme.Colors.completedGray)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(isComplete
                    ? JournalTheme.Colors.successGreen.opacity(0.12)
                    : JournalTheme.Colors.lineLight.opacity(0.5))
        )
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Habit.self, configurations: config)

    let habit = Habit(
        name: "Drink water",
        tier: .mustDo,
        type: .positive,
        successCriteria: "3L",
        currentStreak: 5
    )
    container.mainContext.insert(habit)

    return VStack {
        HabitRowView(
            habit: habit,
            isCompleted: false,
            onToggle: {}
        )

        HabitRowView(
            habit: habit,
            isCompleted: true,
            onToggle: {}
        )
    }
    .linedPaperBackground()
}
