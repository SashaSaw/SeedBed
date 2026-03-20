import SwiftUI
import SwiftData
import UIKit

/// A scroll view that locks scrolling to one axis at a time with a sticky header
struct AxisLockedScrollView<Header: View, Content: View>: UIViewRepresentable {
    let header: Header
    let content: Content
    let allowHorizontalScroll: Bool

    init(allowHorizontalScroll: Bool = true, @ViewBuilder _ header: () -> Header, @ViewBuilder content: () -> Content) {
        self.allowHorizontalScroll = allowHorizontalScroll
        self.header = header()
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear

        // Main scroll view for content
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.isDirectionalLockEnabled = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsHorizontalScrollIndicator = allowHorizontalScroll
        scrollView.showsVerticalScrollIndicator = true
        scrollView.decelerationRate = .fast
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // Store scroll view reference for updates
        context.coordinator.scrollView = scrollView

        // Header hosting controller
        let headerHosting = UIHostingController(rootView: header)
        headerHosting.view.backgroundColor = .clear
        headerHosting.view.translatesAutoresizingMaskIntoConstraints = false

        // Content hosting controller
        let contentHosting = UIHostingController(rootView: content)
        contentHosting.view.backgroundColor = .clear
        contentHosting.view.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(contentHosting.view)
        containerView.addSubview(scrollView)
        containerView.addSubview(headerHosting.view)

        // Store references
        context.coordinator.contentHosting = contentHosting
        context.coordinator.headerHosting = headerHosting
        context.coordinator.headerView = headerHosting.view
        context.coordinator.allowHorizontalScroll = allowHorizontalScroll

        // Width constraints (used when horizontal scroll is disabled to keep content aligned)
        let contentWidthConstraint = contentHosting.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        contentWidthConstraint.isActive = !allowHorizontalScroll
        context.coordinator.contentWidthConstraint = contentWidthConstraint

        let headerWidthConstraint = headerHosting.view.widthAnchor.constraint(equalTo: containerView.widthAnchor)
        headerWidthConstraint.isActive = !allowHorizontalScroll
        context.coordinator.headerWidthConstraint = headerWidthConstraint

        NSLayoutConstraint.activate([
            // Header at top, clips to container bounds horizontally
            headerHosting.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            headerHosting.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),

            // Scroll view fills container but starts below header
            scrollView.topAnchor.constraint(equalTo: headerHosting.view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            // Content inside scroll view
            contentHosting.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentHosting.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentHosting.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentHosting.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
        ])

        return containerView
    }

    func updateUIView(_ containerView: UIView, context: Context) {
        context.coordinator.contentHosting?.rootView = content
        context.coordinator.headerHosting?.rootView = header
        context.coordinator.allowHorizontalScroll = allowHorizontalScroll

        // Update width constraints based on horizontal scroll setting
        context.coordinator.contentWidthConstraint?.isActive = !allowHorizontalScroll
        context.coordinator.headerWidthConstraint?.isActive = !allowHorizontalScroll

        // Update scroll view horizontal scroll capability
        if let scrollView = context.coordinator.scrollView {
            scrollView.showsHorizontalScrollIndicator = allowHorizontalScroll
            // Reset horizontal offset if horizontal scroll is disabled
            if !allowHorizontalScroll {
                scrollView.contentOffset.x = 0
                context.coordinator.headerView?.transform = .identity
            }
        }

        // Force layout update to recalculate content size
        context.coordinator.contentHosting?.view.invalidateIntrinsicContentSize()
        context.coordinator.headerHosting?.view.invalidateIntrinsicContentSize()
        containerView.setNeedsLayout()
        containerView.layoutIfNeeded()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var contentHosting: UIHostingController<Content>?
        var headerHosting: UIHostingController<Header>?
        var headerView: UIView?
        var scrollView: UIScrollView?
        var contentWidthConstraint: NSLayoutConstraint?
        var headerWidthConstraint: NSLayoutConstraint?
        var allowHorizontalScroll: Bool = true
        private var isDecelerating = false

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            if isDecelerating {
                scrollView.setContentOffset(scrollView.contentOffset, animated: false)
            }
            isDecelerating = false
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // If horizontal scroll is disabled, prevent horizontal movement
            if !allowHorizontalScroll && scrollView.contentOffset.x != 0 {
                scrollView.contentOffset.x = 0
            }
            // Sync header horizontal position with scroll view
            headerView?.transform = CGAffineTransform(translationX: -scrollView.contentOffset.x, y: 0)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            isDecelerating = decelerate
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            isDecelerating = false
        }
    }
}

/// Month Grid View showing habit completion over the month
struct MonthGridView: View {
    @Bindable var store: HabitStore
    @State private var selectedMonth = Date()
    @State private var showingNiceToDoGrid = false

    init(store: HabitStore) {
        self.store = store
        // Configure navigation bar title color and font
        let navTitleFont = UIFont(name: "PatrickHand-Regular", size: 17) ?? UIFont.systemFont(ofSize: 17)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(JournalTheme.Colors.inkBlack),
            .font: navTitleFont
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(JournalTheme.Colors.inkBlack),
            .font: UIFont(name: "PatrickHand-Regular", size: 34) ?? UIFont.systemFont(ofSize: 34)
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        NavigationStack {
            MonthGridContentView(
                store: store,
                selectedMonth: $selectedMonth,
                showMustDos: !showingNiceToDoGrid
            )
            .navigationTitle(showingNiceToDoGrid ? "Nice To Do" : "Must Do")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Feedback.selection()
                        withAnimation {
                            showingNiceToDoGrid.toggle()
                        }
                    } label: {
                        Text(showingNiceToDoGrid ? "Must Do" : "Nice To Do")
                            .font(.custom("PatrickHand-Regular", size: 14))
                            .foregroundStyle(JournalTheme.Colors.inkBlue)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        HelpButton(section: .monthGrid)

                        Button {
                            Feedback.selection()
                            withAnimation {
                                selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundStyle(JournalTheme.Colors.inkBlue)
                        }

                        Button {
                            Feedback.selection()
                            withAnimation {
                                selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(JournalTheme.Colors.inkBlue)
                        }
                    }
                }
            }
            .tint(JournalTheme.Colors.inkBlue)
        }
    }
}

/// The actual content of the Month Grid
struct MonthGridContentView: View {
    @Bindable var store: HabitStore
    @Binding var selectedMonth: Date
    let showMustDos: Bool

    // Sheet state for hobby log detail
    @State private var selectedHobbyLog: HobbyLogSelection? = nil
    @State private var selectedGroupHobbyLog: GroupHobbyLogSelection? = nil

    // Static formatters for performance
    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    // Standalone habits (not in any group) - positive only
    private var standaloneHabits: [Habit] {
        if showMustDos {
            return store.standalonePositiveMustDoHabits
        } else {
            return store.positiveNiceToDoHabits
        }
    }

    // Groups (only for must-do view)
    private var groups: [HabitGroup] {
        showMustDos ? store.mustDoGroups : []
    }

    // Negative habits (only shown in must-do view)
    private var negativeHabits: [Habit] {
        showMustDos ? store.negativeHabits : []
    }

    private var calendar: Calendar { Calendar.current }

    private var monthDates: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: selectedMonth),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))
        else { return [] }

        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }

    private var hasContent: Bool {
        !standaloneHabits.isEmpty || !groups.isEmpty || !negativeHabits.isEmpty
    }

    /// Determines if horizontal scrolling is needed based on column count
    /// Day column = 66pt, each habit/group column = 68pt
    private var needsHorizontalScroll: Bool {
        let columnCount = standaloneHabits.count + groups.count + negativeHabits.count
        // Enable horizontal scroll when we have more than 4 columns (roughly > 340pt of content)
        return columnCount > 4
    }

    /// Grid cell size from theme (32pt squares)
    private let gridSize: CGFloat = JournalTheme.Dimensions.gridCellSize

    /// Calculates the x-offset where negative habit columns begin
    private var negativeColumnXOffset: CGFloat {
        let margin = gridSize // 32pt left margin
        let dayColumnWidth = gridSize // 32pt
        let habitColumnWidth = gridSize // 32pt per habit
        let positiveColumns = CGFloat(standaloneHabits.count + groups.count)
        return margin + dayColumnWidth + positiveColumns * habitColumnWidth
    }

    var body: some View {
        AxisLockedScrollView(allowHorizontalScroll: needsHorizontalScroll) {
            // Sticky header
            VStack(alignment: .leading, spacing: 0) {
                // Month header (aligned with grid - starts at second column)
                Text(Self.monthFormatter.string(from: selectedMonth))
                    .font(.custom("PatrickHand-Regular", size: 28))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                    .padding(.leading, gridSize) // One grid cell left margin
                    .padding(.vertical, 12)

                if hasContent {
                    HabitHeaderRowView(habits: standaloneHabits, groups: groups, negativeHabits: negativeHabits, needsHorizontalScroll: needsHorizontalScroll)
                }
            }
        } content: {
            // Scrollable content
            VStack(alignment: .leading, spacing: 0) {
                if !hasContent {
                    Text("No \(showMustDos ? "must-do" : "nice-to-do") habits")
                        .font(JournalTheme.Fonts.habitCriteria())
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                        .padding()
                } else {
                    // Day rows
                    ForEach(monthDates, id: \.self) { date in
                        DayRowView(
                            date: date,
                            habits: standaloneHabits,
                            groups: groups,
                            negativeHabits: negativeHabits,
                            allHabits: store.recurringHabits,
                            isGoodDay: showMustDos ? store.isGoodDay(for: date) : false,
                            showGoodDayHighlight: showMustDos,
                            needsHorizontalScroll: needsHorizontalScroll,
                            onHobbyTap: { habit, date in
                                selectedHobbyLog = HobbyLogSelection(habit: habit, date: date)
                            },
                            onGroupHobbyTap: { group, date in
                                selectedGroupHobbyLog = GroupHobbyLogSelection(group: group, date: date, allHabits: store.recurringHabits)
                            }
                        )
                    }
                }
            }
            .overlay {
                // Continuous bold red dotted line for negative column divider
                if !negativeHabits.isEmpty {
                    GeometryReader { geo in
                        Path { path in
                            let x = negativeColumnXOffset - 2.5
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: geo.size.height))
                        }
                        .stroke(
                            JournalTheme.Colors.negativeRedDark,
                            style: StrokeStyle(lineWidth: 2.5, dash: [5, 3])
                        )
                    }
                    .allowsHitTesting(false)
                }
            }
            .padding(.bottom, 100)
        }
        .graphPaperBackground()
        .sheet(item: $selectedHobbyLog) { selection in
            HobbyLogDetailSheet(
                habit: selection.habit,
                date: selection.date,
                onDismiss: {
                    selectedHobbyLog = nil
                }
            )
        }
        .sheet(item: $selectedGroupHobbyLog) { selection in
            GroupHobbyLogSheet(
                group: selection.group,
                date: selection.date,
                habits: selection.habits,
                onDismiss: {
                    selectedGroupHobbyLog = nil
                }
            )
        }
    }
}

/// Header row with habit and group names (vertical titles)
struct HabitHeaderRowView: View {
    let habits: [Habit]
    let groups: [HabitGroup]
    let negativeHabits: [Habit]
    let needsHorizontalScroll: Bool

    private let gridSize: CGFloat = JournalTheme.Dimensions.gridCellSize // 32pt

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // Left margin (one grid cell)
            Spacer()
                .frame(width: gridSize)

            // Day column header
            Text("Day")
                .font(JournalTheme.Fonts.sectionHeader())
                .foregroundStyle(JournalTheme.Colors.inkBlue)
                .frame(width: gridSize, alignment: .leading)

            // Positive habit column headers (vertical, text starts from bottom)
            ForEach(habits) { habit in
                Text(habit.name)
                    .font(.custom("PatrickHand-Regular", size: 10))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(-90), anchor: .topLeading)
                    .frame(width: gridSize, height: 70, alignment: .bottomLeading)
            }

            // Group column headers (vertical, text starts from bottom)
            ForEach(groups) { group in
                Text(group.name)
                    .font(.custom("PatrickHand-Regular", size: 10))
                    .foregroundStyle(JournalTheme.Colors.inkBlue) // Blue to distinguish groups
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(-90), anchor: .topLeading)
                    .frame(width: gridSize, height: 70, alignment: .bottomLeading)
            }

            // Negative habit column headers (vertical, text starts from bottom)
            ForEach(negativeHabits) { habit in
                Text(habit.name)
                    .font(.custom("PatrickHand-Regular", size: 10))
                    .foregroundStyle(JournalTheme.Colors.negativeRedDark)
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(-90), anchor: .topLeading)
                    .frame(width: gridSize, height: 70, alignment: .bottomLeading)
            }

            // Right margin spacer
            Spacer()
                .frame(width: gridSize)
        }
        .modifier(ConditionalFixedSize(enabled: needsHorizontalScroll))
        .frame(height: 80)
        .padding(.vertical, 4)
        .background(Color.clear)
        .overlay {
            // Bold red dotted line in header row area
            if !negativeHabits.isEmpty {
                GeometryReader { geo in
                    let margin = gridSize
                    let dayColumnWidth = gridSize
                    let habitColumnWidth = gridSize
                    let positiveColumns = CGFloat(habits.count + groups.count)
                    let xOffset = margin + dayColumnWidth + positiveColumns * habitColumnWidth - 1

                    Path { path in
                        path.move(to: CGPoint(x: xOffset, y: 0))
                        path.addLine(to: CGPoint(x: xOffset, y: geo.size.height))
                    }
                    .stroke(
                        JournalTheme.Colors.negativeRedDark,
                        style: StrokeStyle(lineWidth: 2.5, dash: [5, 3])
                    )
                }
                .allowsHitTesting(false)
            }
        }
    }
}

/// Conditionally applies fixedSize modifier
struct ConditionalFixedSize: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.fixedSize(horizontal: true, vertical: false)
        } else {
            content
        }
    }
}

/// A single day row in the grid
struct DayRowView: View {
    let date: Date
    let habits: [Habit]
    let groups: [HabitGroup]
    let negativeHabits: [Habit]
    let allHabits: [Habit] // All habits for checking group satisfaction
    let isGoodDay: Bool
    let showGoodDayHighlight: Bool
    let needsHorizontalScroll: Bool
    var onHobbyTap: ((Habit, Date) -> Void)? = nil
    var onGroupHobbyTap: ((HabitGroup, Date) -> Void)? = nil

    private let gridSize: CGFloat = JournalTheme.Dimensions.gridCellSize // 32pt

    // Static formatters for performance
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var isFuture: Bool {
        date > Date()
    }

    var body: some View {
        HStack(spacing: 0) {
            // Content area with background (excludes right margin)
            HStack(spacing: 0) {
                // Left margin (one grid cell)
                Spacer()
                    .frame(width: gridSize)

                // Day number and weekday
                VStack(alignment: .leading, spacing: 0) {
                    Text(Self.dayFormatter.string(from: date))
                        .font(.system(size: 14, weight: isToday ? .bold : .regular, design: .monospaced))
                        .foregroundStyle(isToday ? JournalTheme.Colors.inkBlue : JournalTheme.Colors.inkBlack)

                    Text(Self.weekdayFormatter.string(from: date))
                        .font(.custom("PatrickHand-Regular", size: 9))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }
                .frame(width: gridSize, alignment: .leading)

                // Positive habit completion cells
                ForEach(habits) { habit in
                    let preCreation = Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: habit.createdAt)
                    GridCellView(
                        isCompleted: habit.isCompleted(for: date),
                        habitType: habit.type,
                        isFuture: isFuture,
                        showCross: showGoodDayHighlight, // Only show crosses in must-do view
                        isHobby: habit.isHobby,
                        hasHobbyContent: habit.isHobby && habit.log(for: date)?.hasContent == true,
                        isPreCreation: preCreation
                    )
                    .frame(width: gridSize, height: gridSize)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if habit.isHobby, !isFuture, habit.isCompleted(for: date) {
                            onHobbyTap?(habit, date)
                        }
                    }
                }

                // Group completion cells
                ForEach(groups) { group in
                    let groupHabits = allHabits.filter { group.habitIds.contains($0.id) }
                    let earliestCreation = groupHabits.map { $0.createdAt }.min() ?? Date()
                    let preCreation = Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: earliestCreation)
                    let groupHasHobbyContent = groupHabits.contains { habit in
                        habit.isHobby && habit.isCompleted(for: date) && habit.log(for: date)?.hasContent == true
                    }
                    GridCellView(
                        isCompleted: group.isSatisfied(habits: allHabits, for: date),
                        habitType: .positive, // Groups are always positive
                        isFuture: isFuture,
                        showCross: showGoodDayHighlight,
                        isHobby: groupHasHobbyContent,
                        hasHobbyContent: groupHasHobbyContent,
                        isPreCreation: preCreation
                    )
                    .frame(width: gridSize, height: gridSize)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if groupHasHobbyContent, !isFuture {
                            onGroupHobbyTap?(group, date)
                        }
                    }
                }

                // Negative habit cells (no per-cell background - handled by continuous overlay)
                ForEach(negativeHabits) { habit in
                    let preCreation = Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: habit.createdAt)
                    GridCellView(
                        isCompleted: habit.isCompleted(for: date),
                        habitType: habit.type,
                        isFuture: isFuture,
                        showCross: true, // Always show indicator for negative habits
                        isPreCreation: preCreation
                    )
                    .frame(width: gridSize, height: gridSize)
                }
            }
            .background(
                Group {
                    if showGoodDayHighlight && isGoodDay && !isFuture {
                        JournalTheme.Colors.goodDayGreen.opacity(0.4)
                    } else if isToday {
                        JournalTheme.Colors.lineMedium.opacity(0.2)
                    } else {
                        Color.clear
                    }
                }
            )

            // Right margin spacer (outside background)
            Spacer()
                .frame(width: gridSize)
        }
        .modifier(ConditionalFixedSize(enabled: needsHorizontalScroll))
        .frame(height: gridSize)
    }
}

/// A single cell in the grid showing completion status
struct GridCellView: View {
    let isCompleted: Bool
    let habitType: HabitType
    let isFuture: Bool
    let showCross: Bool
    var isHobby: Bool = false
    var hasHobbyContent: Bool = false
    var isPreCreation: Bool = false // Date is before habit was created

    private let iconSize: CGFloat = 24

    var body: some View {
        ZStack {
            Group {
                if isFuture {
                    // Future dates are empty
                    Color.clear
                } else if isPreCreation {
                    // Before this habit existed — hand-drawn dash
                    HandDrawnDash(size: iconSize)
                } else if habitType == .negative {
                    // Negative habits: inverted logic
                    // Completed = slipped (bad) = cross
                    // Not completed = avoided (good) = dash
                    if isCompleted {
                        HandDrawnCross(size: iconSize, color: JournalTheme.Colors.negativeRedDark)
                    } else {
                        // Show subtle hand-drawn dash to indicate "no slip"
                        HandDrawnDash(size: iconSize, color: JournalTheme.Colors.completedGray.opacity(0.5))
                    }
                } else if isCompleted {
                    // Positive habit completed - show green checkmark
                    HandDrawnCheckmark(size: iconSize, color: JournalTheme.Colors.goodDayGreenDark)
                } else if showCross {
                    // Not completed in must-do view - show cross
                    HandDrawnCross(size: iconSize, color: JournalTheme.Colors.negativeRedDark.opacity(0.6))
                } else {
                    // Not completed in nice-to-do view - empty
                    Color.clear
                }
            }

            // Show indicator for hobbies with content
            if isHobby && isCompleted && hasHobbyContent && !isFuture && !isPreCreation {
                Circle()
                    .fill(JournalTheme.Colors.goodDayGreenDark)
                    .frame(width: 6, height: 6)
                    .offset(x: 10, y: -10)
            }
        }
    }
}


#Preview {
    ContentView()
        .modelContainer(for: [Habit.self, HabitGroup.self, DailyLog.self, DayRecord.self], inMemory: true)
}
