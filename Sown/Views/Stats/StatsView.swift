import SwiftUI
import SwiftData
import Charts
import HealthKit

/// Time period for habit statistics display
enum StatsPeriod: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

/// Statistics and summary view
struct StatsView: View {
    @Bindable var store: HabitStore

    var body: some View {
        NavigationStack {
            StatsContentView(store: store)
                .navigationTitle("Statistics")
        }
    }
}

/// The actual content of the Stats View
struct StatsContentView: View {
    @Bindable var store: HabitStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedPeriod: StatsPeriod = .daily
    @State private var currentDay: Date = Calendar.current.startOfDay(for: Date())

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Good Day Streak at the top
                GoodDayStreakCard(store: store, today: currentDay)

                // Fulfillment Chart
                FulfillmentChartCard(store: store)

                // Period picker
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(StatsPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                // Habit Progress Section
                HabitProgressSection(store: store, period: selectedPeriod, today: currentDay)

                Spacer(minLength: 100)
            }
            .padding()
        }
        .linedPaperBackground()
        .id(currentDay) // Force rebuild when day changes
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                let today = Calendar.current.startOfDay(for: Date())
                if today != currentDay {
                    currentDay = today
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            let today = Calendar.current.startOfDay(for: Date())
            if today != currentDay {
                currentDay = today
            }
        }
    }
}

/// Card showing good day streak
struct GoodDayStreakCard: View {
    let store: HabitStore
    let today: Date
    @State private var currentStreak: Int = 0

    private func calculateStreak() -> Int {
        var streak = 0
        let calendar = Calendar.current
        var date = calendar.startOfDay(for: today)

        // Check if today is a good day
        if store.isGoodDay(for: date) {
            streak = 1
            date = calendar.date(byAdding: .day, value: -1, to: date)!
        } else {
            date = calendar.date(byAdding: .day, value: -1, to: date)!
        }

        // Count backwards (limit to 365 days max to prevent infinite loops)
        var daysChecked = 0
        while store.isGoodDay(for: date) && daysChecked < 365 {
            streak += 1
            date = calendar.date(byAdding: .day, value: -1, to: date)!
            daysChecked += 1
        }

        return streak
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.custom("PatrickHand-Regular", size: 20))
                    .foregroundStyle(.orange)

                Text("Good Day Streak")
                    .font(JournalTheme.Fonts.sectionHeader())
                    .foregroundStyle(JournalTheme.Colors.inkBlue)

                Spacer()
            }

            HStack(alignment: .bottom, spacing: 4) {
                Text("\(currentStreak)")
                    .font(.custom("PatrickHand-Regular", size: 48))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                Text("days")
                    .font(JournalTheme.Fonts.habitName())
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .padding(.bottom, 8)
            }

            if currentStreak > 0 {
                Text("Keep it up! Every good day counts.")
                    .font(JournalTheme.Fonts.habitCriteria())
                    .foregroundStyle(JournalTheme.Colors.completedGray)
            } else {
                Text("Complete all must-dos today to start a streak!")
                    .font(JournalTheme.Fonts.habitCriteria())
                    .foregroundStyle(JournalTheme.Colors.completedGray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.7))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
        .onAppear {
            currentStreak = calculateStreak()
        }
        .onChange(of: today) { _, _ in
            currentStreak = calculateStreak()
        }
    }
}

/// Data point for the fulfillment chart
struct FulfillmentDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Int
}

/// Card showing fulfillment scores over time as a line chart
struct FulfillmentChartCard: View {
    let store: HabitStore

    private var dataPoints: [FulfillmentDataPoint] {
        let notes = store.recentEndOfDayNotes(days: 30)

        return notes.map { note in
            FulfillmentDataPoint(date: note.date, score: note.fulfillmentScore)
        }.sorted { $0.date < $1.date }
    }

    private var averageScore: Double {
        guard !dataPoints.isEmpty else { return 0 }
        let sum = dataPoints.reduce(0) { $0 + $1.score }
        return Double(sum) / Double(dataPoints.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.custom("PatrickHand-Regular", size: 20))
                    .foregroundStyle(JournalTheme.Colors.teal)

                Text("Fulfillment")
                    .font(JournalTheme.Fonts.sectionHeader())
                    .foregroundStyle(JournalTheme.Colors.inkBlue)

                Spacer()

                if !dataPoints.isEmpty {
                    Text("avg \(String(format: "%.1f", averageScore))")
                        .font(JournalTheme.Fonts.habitCriteria())
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }
            }

            if dataPoints.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.custom("PatrickHand-Regular", size: 32))
                        .foregroundStyle(JournalTheme.Colors.completedGray)

                    Text("No reflections yet")
                        .font(JournalTheme.Fonts.habitCriteria())
                        .foregroundStyle(JournalTheme.Colors.completedGray)

                    Text("Write daily reflections in the Journal tab to see your fulfillment trend")
                        .font(JournalTheme.Fonts.habitCriteria())
                        .foregroundStyle(JournalTheme.Colors.completedGray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Line chart
                Chart {
                    ForEach(dataPoints) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Score", point.score)
                        )
                        .foregroundStyle(
                            .linearGradient(
                                colors: [JournalTheme.Colors.negativeRedDark, JournalTheme.Colors.amber, JournalTheme.Colors.goodDayGreenDark],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        AreaMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Score", point.score)
                        )
                        .foregroundStyle(
                            .linearGradient(
                                colors: [JournalTheme.Colors.teal.opacity(0.2), JournalTheme.Colors.teal.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Score", point.score)
                        )
                        .foregroundStyle(chartPointColor(for: point.score))
                        .symbolSize(30)
                    }

                    // Average line
                    RuleMark(y: .value("Average", averageScore))
                        .foregroundStyle(JournalTheme.Colors.completedGray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                }
                .chartYScale(domain: 1...10)
                .chartYAxis {
                    AxisMarks(values: [1, 5, 10]) { _ in
                        AxisValueLabel()
                            .font(.custom("PatrickHand-Regular", size: 10))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                            .foregroundStyle(JournalTheme.Colors.lineLight)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .font(.custom("PatrickHand-Regular", size: 10))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                            .foregroundStyle(JournalTheme.Colors.lineLight)
                    }
                }
                .frame(height: 180)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.7))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }

    private func chartPointColor(for score: Int) -> Color {
        switch score {
        case 1...3: return JournalTheme.Colors.negativeRedDark
        case 4...5: return JournalTheme.Colors.amber
        case 6...7: return JournalTheme.Colors.teal
        case 8...10: return JournalTheme.Colors.goodDayGreenDark
        default: return JournalTheme.Colors.completedGray
        }
    }
}

// MARK: - Habit Progress Section

/// Container for per-habit progress display based on selected period
struct HabitProgressSection: View {
    let store: HabitStore
    let period: StatsPeriod
    let today: Date

    /// Habit display type for sorting priority
    private enum HabitDisplayType: Int {
        case barChart = 0   // Hobbies with success criteria - highest priority
        case negative = 1   // Don't do habits
        case streak = 2     // Regular tick habits - lowest priority
    }

    /// Get the display type for a habit
    private func displayType(for habit: Habit) -> HabitDisplayType {
        if habit.type == .negative {
            return .negative
        }
        // Only bar chart for measure-based criteria or HealthKit, not time-only
        let hasTrackableTarget = hasMeasureBasedCriteria(habit: habit) || habit.isHealthKitLinked
        return hasTrackableTarget ? .barChart : .streak
    }

    /// Check if a habit has measure-based criteria (not just time-based)
    private func hasMeasureBasedCriteria(habit: Habit) -> Bool {
        guard let criteria = habit.successCriteria, !criteria.isEmpty else { return false }
        let entries = CriteriaEditorView.parseCriteriaString(criteria)
        return entries.contains { $0.mode == .measure }
    }

    /// Check if a habit has any data in the last 7 days
    private func hasData(habit: Habit) -> Bool {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        let last7Days = (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: todayStart) }

        for date in last7Days {
            if habit.type == .negative {
                // For negative habits, check if there's any recorded state (slip or clean)
                // A habit has data if it was created before or on this date
                let habitCreationDate = calendar.startOfDay(for: habit.createdAt)
                if date >= habitCreationDate {
                    return true
                }
            } else {
                // For positive habits, check completions or values
                if habit.isCompleted(for: date) || habit.completionValue(for: date) != nil {
                    return true
                }
            }
        }
        return false
    }

    /// Sorted habits: those with data first, then by type priority
    private var sortedHabits: [Habit] {
        store.recurringHabits.sorted { habit1, habit2 in
            let hasData1 = hasData(habit: habit1)
            let hasData2 = hasData(habit: habit2)

            // First sort by whether they have data (with data first)
            if hasData1 != hasData2 {
                return hasData1 && !hasData2
            }

            // Then sort by display type priority
            return displayType(for: habit1).rawValue < displayType(for: habit2).rawValue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Habit Progress")
                .font(JournalTheme.Fonts.sectionHeader())
                .foregroundStyle(JournalTheme.Colors.inkBlue)

            if store.recurringHabits.isEmpty {
                Text("No habits yet")
                    .font(JournalTheme.Fonts.habitCriteria())
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardBackground)
            } else {
                switch period {
                case .daily:
                    let habits = sortedHabits
                    ForEach(habits) { habit in
                        // Negative habits (Don't Do) get their own card showing days clean
                        if habit.type == .negative {
                            DontDoStreakCard(habit: habit, today: today)
                        } else {
                            // Show bar chart only for habits with MEASURE-based criteria or HealthKit
                            // Time-only habits should show as streak cards
                            let hasMeasureCriteria = hasMeasureBasedCriteria(habit: habit)
                            let hasTrackableTarget = hasMeasureCriteria || habit.isHealthKitLinked

                            if hasTrackableTarget {
                                HabitBarChartCard(habit: habit, today: today)
                            } else {
                                HabitStreakCard(habit: habit, today: today)
                            }
                        }
                    }
                    .id(habits.map { $0.id.uuidString }.joined())
                case .weekly, .monthly:
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.custom("PatrickHand-Regular", size: 32))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                        Text("Coming soon")
                            .font(JournalTheme.Fonts.habitCriteria())
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(cardBackground)
                }
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.7))
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Bar Chart Card (for habits with success criteria)

/// Data point for the habit bar chart
struct HabitValueDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double?
    let dayAbbr: String
    let isToday: Bool
}

/// Bar chart card showing 7-day values vs target for habits with success criteria
/// Supports live updates for HealthKit-linked habits
struct HabitBarChartCard: View {
    let habit: Habit
    let today: Date

    /// Live HealthKit value for today (updated periodically)
    @State private var liveHealthKitValue: Double? = nil

    /// Timer for periodic refresh
    @State private var refreshTimer: Timer? = nil

    private var last7Days: [Date] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: todayStart) }.reversed()
    }

    private var dataPoints: [HabitValueDataPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)

        return last7Days.map { date in
            let isToday = calendar.isDate(date, inSameDayAs: todayStart)

            // For today, use live HealthKit value if available
            let value: Double?
            if isToday && habit.isHealthKitLinked && liveHealthKitValue != nil {
                value = liveHealthKitValue
            } else {
                value = habit.completionValue(for: date)
            }

            return HabitValueDataPoint(
                date: date,
                value: value,
                dayAbbr: formatter.string(from: date),
                isToday: isToday
            )
        }
    }

    /// Target value from HealthKit or success criteria
    private var targetValue: Double? {
        // Check HealthKit target first
        if habit.isHealthKitLinked, let target = habit.healthKitTarget {
            return target
        }
        // Fall back to success criteria parsing
        let entries = CriteriaEditorView.parseCriteriaString(habit.successCriteria)
        return entries.first(where: { $0.mode == .measure }).flatMap { Double($0.value) }
    }

    /// Unit from HealthKit or success criteria
    private var unit: String? {
        // Check HealthKit unit first
        if let metric = habit.healthKitMetric {
            return metric.unit
        }
        // Fall back to success criteria
        let entries = CriteriaEditorView.parseCriteriaString(habit.successCriteria)
        if let measureEntry = entries.first(where: { $0.mode == .measure }) {
            return measureEntry.isCustomUnit ? measureEntry.customUnit : measureEntry.unit
        }
        return nil
    }

    /// Whether this is a live-updating habit
    private var isLiveTracking: Bool {
        habit.isHealthKitLinked
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with habit name and live indicator
            HStack {
                Text(habit.name)
                    .font(JournalTheme.Fonts.habitName())
                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                Spacer()

                // Live indicator for HealthKit habits
                if isLiveTracking {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Live")
                            .font(.custom("PatrickHand-Regular", size: 11))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }
                }
            }

                // Bar chart (always show, even if empty)
            Chart {
                ForEach(dataPoints) { dataPoint in
                    BarMark(
                        x: .value("Day", dataPoint.dayAbbr),
                        y: .value("Value", dataPoint.value ?? 0)
                    )
                    .foregroundStyle(barColor(for: dataPoint.value, isToday: dataPoint.isToday))
                    .cornerRadius(4)
                }

                // Target line
                if let target = targetValue {
                    RuleMark(y: .value("Target", target))
                        .foregroundStyle(.orange.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Goal")
                                .font(.custom("PatrickHand-Regular", size: 10))
                                .foregroundStyle(.orange)
                        }
                }
            }
            .chartYScale(domain: 0...(targetValue ?? 100))
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.custom("PatrickHand-Regular", size: 10))
                        .foregroundStyle(JournalTheme.Colors.inkBlack)
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                        .foregroundStyle(JournalTheme.Colors.lineLight)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.custom("PatrickHand-Regular", size: 10))
                        .foregroundStyle(JournalTheme.Colors.inkBlack)
                }
            }
            .frame(height: 120)

            // Unit label with current value for live tracking
            HStack {
                if let unit = unit {
                    Text("in \(unit)")
                        .font(.custom("PatrickHand-Regular", size: 12))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }

                Spacer()

                // Show current progress for live tracking
                if isLiveTracking, let current = liveHealthKitValue, let target = targetValue {
                    let progress = min(current / target, 1.0)
                    Text("\(Int(progress * 100))% of goal")
                        .font(.custom("PatrickHand-Regular", size: 12))
                        .foregroundStyle(progress >= 1.0 ? JournalTheme.Colors.goodDayGreenDark : JournalTheme.Colors.completedGray)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.7))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
        .onAppear {
            if habit.isHealthKitLinked {
                fetchLiveHealthKitValue()
                startRefreshTimer()
            }
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }

    // MARK: - HealthKit Live Data

    private func fetchLiveHealthKitValue() {
        guard let metric = habit.healthKitMetric else { return }

        Task {
            if let value = await HealthKitManager.shared.fetchTodayValue(for: metric) {
                await MainActor.run {
                    liveHealthKitValue = value
                }
            }
        }
    }

    private func startRefreshTimer() {
        // Refresh every 30 seconds for live data
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            fetchLiveHealthKitValue()
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func barColor(for value: Double?, isToday: Bool) -> Color {
        guard let value = value else {
            return JournalTheme.Colors.lineLight
        }
        guard let target = targetValue else {
            return JournalTheme.Colors.inkBlue
        }

        // Use a different shade for today's live bar to indicate it's in progress
        if isToday && isLiveTracking && value < target {
            return JournalTheme.Colors.inkBlue.opacity(0.7)
        }

        return value >= target ? JournalTheme.Colors.goodDayGreenDark : JournalTheme.Colors.amber
    }
}

// MARK: - Streak Card (for habits without success criteria)

/// 7-day streak view with flames for consecutive completions
struct HabitStreakCard: View {
    let habit: Habit
    let today: Date

    private var last7Days: [Date] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: todayStart) }.reversed()
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }

    /// Calculate streak counts for each day in the 7-day window
    /// Returns an array where each element is the streak count ending at that day (0 if not completed)
    private var streakCounts: [Int] {
        var counts: [Int] = []
        var currentStreak = 0

        for date in last7Days {
            if habit.isCompleted(for: date) {
                currentStreak += 1
                counts.append(currentStreak)
            } else {
                currentStreak = 0
                counts.append(0)
            }
        }

        return counts
    }

    /// Check if a day at given index is part of a consecutive streak (count >= 2)
    private func isPartOfStreak(at index: Int) -> Bool {
        let counts = streakCounts
        guard index < counts.count else { return false }
        return counts[index] >= 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with habit name and best streak badge
            HStack {
                Text(habit.name)
                    .font(JournalTheme.Fonts.habitName())
                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                Spacer()

                // Best streak badge
                if habit.bestStreak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 11))
                        Text("\(habit.bestStreak)")
                            .font(.custom("PatrickHand-Regular", size: 13))
                    }
                    .foregroundStyle(JournalTheme.Colors.amber)
                }
            }

            // 7-day row with flames for consecutive days
            HStack(spacing: 8) {
                ForEach(Array(last7Days.enumerated()), id: \.offset) { index, date in
                    VStack(spacing: 4) {
                        Text(dayFormatter.string(from: date))
                            .font(.custom("PatrickHand-Regular", size: 10))
                            .foregroundStyle(JournalTheme.Colors.completedGray)

                        let isCompleted = habit.isCompleted(for: date)
                        let partOfStreak = isPartOfStreak(at: index)
                        let streakCount = streakCounts[index]

                        if isCompleted {
                            if partOfStreak {
                                // Flame with streak count inside
                                ZStack {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.orange)

                                    Text("\(streakCount)")
                                        .font(.custom("PatrickHand-Regular", size: 9))
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                        .offset(y: 1)
                                }
                                .frame(width: 26, height: 26)
                            } else {
                                // Single completed day (not part of streak)
                                HandDrawnCheckmark(size: 22, color: JournalTheme.Colors.inkBlue)
                                    .frame(width: 26, height: 26)
                            }
                        } else {
                            // Not completed
                            Circle()
                                .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Current streak display
            if habit.currentStreak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text("\(habit.currentStreak) day streak")
                        .font(.custom("PatrickHand-Regular", size: 14))
                        .foregroundStyle(JournalTheme.Colors.completedGray)

                    if habit.bestStreak > habit.currentStreak {
                        Text("(best: \(habit.bestStreak))")
                            .font(.custom("PatrickHand-Regular", size: 12))
                            .foregroundStyle(JournalTheme.Colors.completedGray.opacity(0.7))
                    }
                }
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

// MARK: - Don't Do Streak Card (for negative habits)

/// Card showing days since last slip for Don't Do habits
struct DontDoStreakCard: View {
    let habit: Habit
    let today: Date

    private var last7Days: [Date] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: todayStart) }.reversed()
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }

    /// Calculate days since last slip (completion = slip for negative habits)
    /// Returns days since last slip, or days since habit creation if never slipped
    private var daysSinceLastSlip: Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)

        // Check if slipped today
        if habit.isCompleted(for: todayStart) {
            return 0
        }

        // Look back through history to find last slip
        var daysClean = 0

        // Limit to 365 days or habit creation date
        let habitCreationDate = calendar.startOfDay(for: habit.createdAt)
        let maxDaysToCheck = min(365, calendar.dateComponents([.day], from: habitCreationDate, to: todayStart).day ?? 365)

        for dayOffset in 0..<maxDaysToCheck {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: todayStart) else { break }

            // Stop if we've gone before the habit was created
            if date < habitCreationDate {
                break
            }

            if habit.isCompleted(for: date) {
                // Found a slip - return days since then
                return dayOffset
            }
            daysClean = dayOffset + 1
        }

        // Never slipped - return days since habit creation
        return daysClean
    }

    /// Best clean streak (longest period without slipping)
    private var bestCleanStreak: Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        let habitCreationDate = calendar.startOfDay(for: habit.createdAt)

        var bestStreak = 0
        var currentStreak = 0

        // Look through all days since habit creation
        let totalDays = calendar.dateComponents([.day], from: habitCreationDate, to: todayStart).day ?? 0

        for dayOffset in 0...totalDays {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: habitCreationDate) else { break }

            if habit.isCompleted(for: date) {
                // Slipped - reset current streak
                currentStreak = 0
            } else {
                // Clean day - increment streak
                currentStreak += 1
                bestStreak = max(bestStreak, currentStreak)
            }
        }

        return bestStreak
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with habit name and best streak
            HStack {
                Text(habit.name)
                    .font(JournalTheme.Fonts.habitName())
                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                Spacer()

                // Best clean streak badge
                if bestCleanStreak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 11))
                        Text("\(bestCleanStreak)")
                            .font(.custom("PatrickHand-Regular", size: 13))
                    }
                    .foregroundStyle(JournalTheme.Colors.amber)
                }
            }

            // 7-day view showing clean days vs slips
            HStack(spacing: 8) {
                ForEach(Array(last7Days.enumerated()), id: \.offset) { index, date in
                    VStack(spacing: 4) {
                        Text(dayFormatter.string(from: date))
                            .font(.custom("PatrickHand-Regular", size: 10))
                            .foregroundStyle(JournalTheme.Colors.completedGray)

                        let slipped = habit.isCompleted(for: date)

                        if slipped {
                            // Slipped - show X mark in red
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(JournalTheme.Colors.negativeRedDark)
                                .frame(width: 22, height: 22)
                        } else {
                            // Clean day - show checkmark in green
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(JournalTheme.Colors.goodDayGreenDark)
                                .frame(width: 22, height: 22)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Days clean counter
            HStack(spacing: 6) {
                if daysSinceLastSlip > 0 {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(JournalTheme.Colors.goodDayGreenDark)

                    Text("\(daysSinceLastSlip) day\(daysSinceLastSlip == 1 ? "" : "s") clean")
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(JournalTheme.Colors.goodDayGreenDark)

                    if bestCleanStreak > daysSinceLastSlip {
                        Text("(best: \(bestCleanStreak))")
                            .font(.custom("PatrickHand-Regular", size: 12))
                            .foregroundStyle(JournalTheme.Colors.completedGray.opacity(0.7))
                    }
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(JournalTheme.Colors.negativeRedDark)

                    Text("Slipped today")
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(JournalTheme.Colors.negativeRedDark)
                }
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

#Preview {
    ContentView()
        .modelContainer(for: [Habit.self, HabitGroup.self, DailyLog.self, DayRecord.self, EndOfDayNote.self], inMemory: true)
}
