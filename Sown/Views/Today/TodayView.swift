import SwiftUI
import SwiftData
import Combine

/// Main Today View showing all habits for the current day
struct TodayView: View {
    @Bindable var store: HabitStore

    var body: some View {
        NavigationStack {
            TodayContentView(store: store)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// The actual content of the Today View - aligns text to paper lines
struct TodayContentView: View {
    @Bindable var store: HabitStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("userName") private var userName = ""
    @State private var selectedDate = Date()
    @State private var lastKnownDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedHabit: Habit?
    @State private var selectedGroup: HabitGroup?

    // Alert state for deleting empty groups
    @State private var groupToDeleteAfterHabit: HabitGroup? = nil
    @State private var showDeleteGroupAlert: Bool = false

    // Celebration state
    @State private var showCelebration: Bool = false
    @State private var wasGoodDay: Bool = false
    @State private var pendingCelebration: Bool = false  // Deferred celebration waiting for hobby overlay

    // Hobby completion overlay state
    @State private var showHobbyOverlay: Bool = false
    @State private var completingHobby: Habit? = nil

    // Success criteria overlay state
    @State private var showCriteriaOverlay: Bool = false
    @State private var criteriaHabit: Habit? = nil

    // Sub-habit picker overlay state (group header swipe)
    @State private var showSubHabitPicker: Bool = false
    @State private var subHabitPickerGroup: HabitGroup? = nil

    // Quick-add sheets
    @State private var showingAddHabit: Bool = false
    @State private var showingAddMustDo: Bool = false
    @State private var showingAddNiceToDo: Bool = false
    @State private var showingAddTodayTask: Bool = false
    @State private var showingAddDontDo: Bool = false

    // First-time group callout (lightbulb tip)
    @AppStorage("hasSeenGroupCallout") private var hasSeenGroupCallout: Bool = false
    @State private var showGroupCallout: Bool = false

    // First-time gesture tutorial
    @AppStorage("hasSeenGestureTutorial") private var hasSeenGestureTutorial: Bool = false
    @State private var showGestureTutorial: Bool = false

    // Block setup sheet
    @State private var showingBlockSetup: Bool = false

    // End of day reflection
    @State private var showingReflection: Bool = false
    @State private var blockSettings = BlockSettings.shared

    // Group selection mode
    @State private var isSelectingForGroup: Bool = false
    @State private var selectedHabitIdsForGroup: Set<UUID> = []
    @State private var showingAddGroup: Bool = false

    // Morning tasks prompt
    @State private var showingMorningTasks: Bool = false
    @AppStorage("lastMorningPromptDate") private var lastMorningPromptDate: String = ""
    private var schedule: UserSchedule { UserSchedule.shared }

    // Sort mode for Today view
    @AppStorage("todaySortMode") private var sortModeRaw: String = TodaySortMode.byType.rawValue
    private var sortMode: TodaySortMode {
        TodaySortMode(rawValue: sortModeRaw) ?? .byType
    }

    // Track if we've already locked previous day this session (debounce)
    @State private var hasLockedPreviousDay: Bool = false

    // HealthKit integration
    @State private var healthKitManager = HealthKitManager.shared
    @State private var healthKitCancellable: AnyCancellable?

    // Screen Time integration
    @State private var screenTimeManager = ScreenTimeManager.shared


    private let lineHeight = JournalTheme.Dimensions.lineSpacing
    private let contentPadding: CGFloat = 24

    /// Whether the done section has any content (completed must-do, nice-to-do, or tasks)
    private var hasDoneContent: Bool {
        !store.completedStandaloneMustDoHabits(for: selectedDate).isEmpty ||
        !store.completedNiceToDoHabits(for: selectedDate).isEmpty ||
        !store.todayCompletedTasks.isEmpty
    }

    /// Whether the today-only section has any content (uncompleted tasks)
    private var hasTodayOnlyContent: Bool {
        !store.todayVisibleTasks.isEmpty
    }

    /// Whether any today tasks have ever been added (some may be completed now)
    private var hasAnyTodayTasks: Bool {
        hasTodayOnlyContent || !store.todayCompletedTasks.isEmpty
    }

    /// Whether the "New today task" button should appear in a section (vs toolbar)
    private var showTodayTaskButtonInSection: Bool {
        hasAnyTodayTasks
    }

    var body: some View {
        ZStack {
            // Paper background
            LinedPaperBackground(lineSpacing: lineHeight)
                .ignoresSafeArea()

            // Scrollable content
            ScrollView {
                VStack(spacing: 0) {
                    // Header — left aligned with sort button on right
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 0) {
                            if !userName.isEmpty {
                                Text(greetingText)
                                    .font(.custom("PatrickHand-Regular", size: 15))
                                    .foregroundStyle(JournalTheme.Colors.completedGray)
                                    .padding(.bottom, 2)
                            }

                            Text("Todays to-dos")
                                .font(JournalTheme.Fonts.title())
                                .foregroundStyle(JournalTheme.Colors.inkBlack)

                            Text(formattedDate)
                                .font(.custom("PatrickHand-Regular", size: 15))
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                                .padding(.top, 4)
                        }

                        Spacer()

                        // Sort mode toggle button
                        Button {
                            Feedback.selection()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                sortModeRaw = (sortMode == .byType)
                                    ? TodaySortMode.byTimeOfDay.rawValue
                                    : TodaySortMode.byType.rawValue
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(JournalTheme.Colors.inkBlue)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, contentPadding)
                    .padding(.top, userName.isEmpty ? lineHeight : lineHeight / 2)
                    .padding(.bottom, 8)

                    // Streak tracker bar
                    streakTrackerBar

                    // Block status indicator
                    blockStatusBanner

                    // Sections - conditionally show by type or by time of day
                    VStack(spacing: 24) {
                        if sortMode == .byType {
                            // Original "By Type" layout
                            // ◇ TODAY ONLY Section (uncompleted tasks only)
                            todayOnlySection

                            // ★ MUST DO Section
                            mustDoSection

                            // NICE TO DO Section (uncompleted only)
                            niceToDoSection

                            // DON'T DO Section (negative habits)
                            dontDoSection

                            // DONE ✓ Section (completed nice-to-do + completed tasks)
                            doneSection
                        } else {
                            // "By Time of Day" layout
                            // ◇ TODAY ONLY Section stays at top
                            todayOnlySection

                            // ⏰ ANYTIME Section (habits without schedule times)
                            anytimeSection

                            // Time slot sections
                            ForEach(TimeSlot.allCases, id: \.self) { slot in
                                timeSlotSection(for: slot)
                            }

                            // DON'T DO Section stays separate
                            dontDoSection

                            // DONE ✓ Section
                            doneSection
                        }

                        // Daily reflection button
                        reflectionButton
                    }
                    .padding(.top, 16)
                    .animation(.easeInOut(duration: 0.3), value: sortMode)

                    // Empty state
                    if store.habits.isEmpty {
                        VStack(spacing: 8) {
                            Text("No habits yet")
                                .font(JournalTheme.Fonts.habitName())
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                            Text("Tap '+ New must-do' to add your first habit")
                                .font(JournalTheme.Fonts.habitCriteria())
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }

                    Spacer(minLength: 120)
                }
            }

            // Celebration overlay
            if showCelebration {
                CelebrationOverlay(isShowing: $showCelebration)
            }

            // Hobby completion overlay
            if showHobbyOverlay, let hobby = completingHobby {
                HobbyCompletionOverlay(
                    habit: hobby,
                    onSave: { note, images in
                        store.saveHobbyCompletion(for: hobby, on: selectedDate, note: note, images: images)
                        showHobbyOverlay = false
                        completingHobby = nil
                        // Trigger deferred celebration after hobby overlay dismisses
                        if pendingCelebration {
                            pendingCelebration = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation { showCelebration = true }
                                Feedback.celebration()
                            }
                        }
                    },
                    onDismiss: {
                        showHobbyOverlay = false
                        completingHobby = nil
                        // Trigger deferred celebration after hobby overlay dismisses
                        if pendingCelebration {
                            pendingCelebration = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation { showCelebration = true }
                                Feedback.celebration()
                            }
                        }
                    }
                )
            }

            // Success criteria overlay
            if showCriteriaOverlay, let habit = criteriaHabit {
                SuccessCriteriaOverlay(
                    habit: habit,
                    onSave: { value in
                        // Persist the entered value to DailyLog
                        if let value = value {
                            store.setCompletion(for: habit, completed: true, value: value, on: selectedDate)
                        }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCriteriaOverlay = false
                        }
                        // Proceed to notes overlay if enabled, otherwise just dismiss
                        if habit.isHobby || habit.enableNotesPhotos {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                completingHobby = habit
                                showHobbyOverlay = true
                                criteriaHabit = nil
                            }
                        } else {
                            criteriaHabit = nil
                            // Trigger deferred celebration if pending
                            if pendingCelebration {
                                pendingCelebration = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation { showCelebration = true }
                                    Feedback.celebration()
                                }
                            }
                        }
                    },
                    onCancel: {
                        // Uncross the habit
                        store.setCompletion(for: habit, completed: false, on: selectedDate)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCriteriaOverlay = false
                        }
                        criteriaHabit = nil
                    }
                )
                .transition(.opacity)
                .zIndex(100)
            }

            // Sub-habit picker overlay (group header swipe)
            if showSubHabitPicker, let group = subHabitPickerGroup {
                let uncompletedHabits = store.habits(for: group).filter { !$0.isCompleted(for: selectedDate) }
                SubHabitSelectionOverlay(
                    group: group,
                    habits: uncompletedHabits,
                    onSelect: { habit in
                        store.setCompletion(for: habit, completed: true, on: selectedDate)
                        store.recordSelectedOption(for: habit, option: habit.name, on: selectedDate)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSubHabitPicker = false
                        }
                        subHabitPickerGroup = nil
                        handleCompletionOverlay(for: habit)
                    },
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSubHabitPicker = false
                        }
                        subHabitPickerGroup = nil
                    }
                )
                .transition(.opacity)
                .zIndex(99)
            }

            // Floating "Create Group" button during selection mode
            if isSelectingForGroup && selectedHabitIdsForGroup.count >= 2 {
                VStack {
                    Spacer()

                    Button {
                        Feedback.buttonPress()
                        showingAddGroup = true
                    } label: {
                        Text("Create Group")
                            .font(.custom("PatrickHand-Regular", size: 17))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(JournalTheme.Colors.inkBlue)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, contentPadding)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Gesture tutorial overlay (first time only)
            if showGestureTutorial {
                GestureTutorialOverlay {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showGestureTutorial = false
                    }
                    hasSeenGestureTutorial = true
                }
                .transition(.opacity)
                .zIndex(200)
            }
        }
        .sheet(item: $selectedHabit) { habit in
            NavigationStack {
                HabitDetailView(store: store, habit: habit)
            }
            .onAppear { Feedback.sheetOpen() }
        }
        .sheet(item: $selectedGroup) { group in
            GroupDetailSheet(
                group: group,
                store: store,
                onDismiss: { selectedGroup = nil }
            )
            .onAppear { Feedback.sheetOpen() }
        }
        .sheet(isPresented: $showingAddHabit) {
            AddHabitView(store: store)
                .onAppear { Feedback.sheetOpen() }
        }
        .sheet(isPresented: $showingAddMustDo) {
            AddMustDoView(store: store)
                .onAppear { Feedback.sheetOpen() }
        }
        .sheet(isPresented: $showingAddNiceToDo) {
            AddNiceToDoView(store: store)
                .onAppear { Feedback.sheetOpen() }
        }
        .sheet(isPresented: $showingAddTodayTask) {
            AddTodayTaskView(store: store)
                .onAppear { Feedback.sheetOpen() }
        }
        .sheet(isPresented: $showingAddDontDo) {
            AddDontDoView(store: store)
                .onAppear { Feedback.sheetOpen() }
        }
        .sheet(isPresented: $showingReflection) {
            EndOfDayNoteView(
                store: store,
                date: selectedDate,
                onDismiss: { showingReflection = false }
            )
            .onAppear { Feedback.sheetOpen() }
        }
        .sheet(isPresented: $showingBlockSetup) {
            BlockSetupView()
                .onAppear { Feedback.sheetOpen() }
        }
        .sheet(isPresented: $showingAddGroup) {
            AddGroupView(store: store, selectedHabitIds: selectedHabitIdsForGroup) {
                // On completion, exit selection mode
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSelectingForGroup = false
                    selectedHabitIdsForGroup.removeAll()
                }
            }
            .onAppear { Feedback.sheetOpen() }
        }
        .fullScreenCover(isPresented: $showingMorningTasks) {
            MorningTasksView(store: store) {
                showingMorningTasks = false
            }
            .onAppear { Feedback.sheetOpen() }
        }
        .toolbar {
            // Show "+" button in top right when neither today-only nor done section exists
            if !showTodayTaskButtonInSection {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Feedback.buttonPress()
                        showingAddHabit = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.custom("PatrickHand-Regular", size: 16))
                            .foregroundStyle(JournalTheme.Colors.inkBlue)
                    }
                }
            }
        }
        .alert("Delete Empty Group?", isPresented: $showDeleteGroupAlert) {
            Button("Keep Group") {
                groupToDeleteAfterHabit = nil
            }
            Button("Delete Group", role: .destructive) {
                if let group = groupToDeleteAfterHabit {
                    store.deleteGroup(group)
                }
                groupToDeleteAfterHabit = nil
            }
        } message: {
            Text("The group '\(groupToDeleteAfterHabit?.name ?? "")' is now empty. Would you like to delete it?")
        }
        .onAppear {
            // Lock yesterday's good day on app launch (only once per session)
            if !hasLockedPreviousDay {
                store.lockPreviousDayIfNeeded()
                hasLockedPreviousDay = true
            }
            wasGoodDay = store.isGoodDay(for: selectedDate)
            // Show group callout if first time seeing a group
            if !hasSeenGroupCallout && !store.groups.isEmpty {
                withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
                    showGroupCallout = true
                }
            }
            // Check for morning tasks prompt
            checkMorningTasksPrompt()

            // Show gesture tutorial on first visit (with delay, only if no other overlays)
            if !hasSeenGestureTutorial && !showCelebration && !showHobbyOverlay && !showCriteriaOverlay {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    guard !hasSeenGestureTutorial else { return }
                    withAnimation(.easeIn(duration: 0.3)) {
                        showGestureTutorial = true
                    }
                }
            }

            // Set up HealthKit integration
            setupHealthKitObserver()

            // Set up Screen Time integration
            setupScreenTimeObserver()
        }
        .onDisappear {
            // Clean up HealthKit observer
            healthKitCancellable?.cancel()
            healthKitCancellable = nil
        }
        .onChange(of: store.completionChangeCounter) { _, _ in
            let isNowGoodDay = store.isGoodDay(for: selectedDate)
            if isNowGoodDay && !wasGoodDay {
                // If an overlay is showing, defer celebration until it's dismissed
                if showHobbyOverlay || showCriteriaOverlay {
                    pendingCelebration = true
                } else {
                    withAnimation {
                        showCelebration = true
                    }
                    Feedback.celebration()
                }
            }
            wasGoodDay = isNowGoodDay
        }
        .onChange(of: selectedHabitIdsForGroup) { _, newValue in
            if newValue.isEmpty && isSelectingForGroup {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSelectingForGroup = false
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                let today = Calendar.current.startOfDay(for: Date())
                if today != lastKnownDay {
                    // Lock yesterday's good day status before switching to today
                    store.lockPreviousDayIfNeeded()
                    selectedDate = Date()
                    lastKnownDay = today
                    wasGoodDay = store.isGoodDay(for: selectedDate)
                }
                // Check for morning tasks prompt when returning to app
                checkMorningTasksPrompt()

                // Refresh HealthKit values when app becomes active (background thread)
                let manager = healthKitManager
                let metrics = store.activeHealthKitMetrics
                Task.detached(priority: .userInitiated) { [weak store] in
                    await manager.refreshValues(for: metrics)
                    await MainActor.run {
                        store?.checkHealthKitCompletions(triggerNotification: false)
                    }
                }

                // Check Screen Time completions when app becomes active
                store.checkScreenTimeCompletions(triggerNotification: false)

                // Sync failure-blocked apps from extension
                ScreenTimeManager.shared.syncFailureBlockedApps()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            let today = Calendar.current.startOfDay(for: Date())
            if today != lastKnownDay {
                store.lockPreviousDayIfNeeded()
                selectedDate = Date()
                lastKnownDay = today
                wasGoodDay = store.isGoodDay(for: selectedDate)

                // Clear failure blocks at midnight
                ScreenTimeManager.shared.clearFailureBlocks()
                ScreenTimeUsageManager.shared.clearSlippedHabits(for: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: selectedDate)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        if hour < 12 {
            timeOfDay = "Good morning"
        } else if hour < 17 {
            timeOfDay = "Good afternoon"
        } else {
            timeOfDay = "Good evening"
        }
        return "\(timeOfDay), \(userName)!"
    }

    // MARK: - HealthKit Integration

    /// Set up HealthKit observer for auto-completion
    private func setupHealthKitObserver() {
        guard healthKitManager.isAuthorized else { return }

        let activeMetrics = store.activeHealthKitMetrics
        guard !activeMetrics.isEmpty else { return }

        // Enable background delivery for active metrics (run on background thread to avoid blocking UI)
        let manager = healthKitManager
        Task.detached(priority: .userInitiated) {
            manager.enableBackgroundDelivery(for: activeMetrics)
        }

        // Initial fetch on background thread
        Task.detached(priority: .userInitiated) { [weak store] in
            await manager.refreshValues(for: activeMetrics)
            await MainActor.run {
                store?.checkHealthKitCompletions(triggerNotification: false)
            }
        }

        // Subscribe to value updates
        healthKitCancellable = healthKitManager.valueUpdatesPublisher
            .receive(on: RunLoop.main)
            .sink { [weak store] _ in
                store?.checkHealthKitCompletions(triggerNotification: true)
            }
    }

    // MARK: - Screen Time Integration

    /// Set up Screen Time monitoring for habit auto-completion
    private func setupScreenTimeObserver() {
        guard screenTimeManager.isAuthorized else { return }

        let linkedHabits = store.screenTimeLinkedHabits
        guard !linkedHabits.isEmpty else { return }

        // Start monitoring all linked habits
        store.startScreenTimeMonitoring()

        // Check for any completions that happened while app was closed
        store.checkScreenTimeCompletions(triggerNotification: false)
    }

    // MARK: - Morning Tasks Prompt

    /// Show the morning tasks prompt once per day, on the first open after wake time
    private func checkMorningTasksPrompt() {
        let calendar = Calendar.current
        let now = Date()
        let todayString = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: now)
        }()

        // Already shown today
        guard lastMorningPromptDate != todayString else { return }

        // Check if current time is after wake time
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        guard currentMinutes >= schedule.wakeTimeMinutes else { return }

        // Only show before noon (12:00 PM = 720 minutes)
        guard currentMinutes < 720 else { return }

        // Only show if no tasks exist yet
        guard store.todayVisibleTasks.isEmpty else { return }

        // Mark as shown and present after a brief delay
        lastMorningPromptDate = todayString
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showingMorningTasks = true
        }
    }

    // MARK: - Completion Overlay Flow

    /// Handles the post-swipe overlay flow for a habit:
    /// 1. If successCriteria → show criteria overlay (which chains to notes if needed)
    /// 2. Else if isHobby/enableNotesPhotos → show hobby overlay
    /// 3. Else → nothing extra
    private func handleCompletionOverlay(for habit: Habit) {
        if let criteria = habit.successCriteria, !criteria.isEmpty {
            criteriaHabit = habit
            withAnimation(.easeInOut(duration: 0.2)) {
                showCriteriaOverlay = true
            }
        } else if habit.isHobby || habit.enableNotesPhotos {
            completingHobby = habit
            showHobbyOverlay = true
        }
    }

    // MARK: - Streak Tracker Bar

    private var streakTrackerBar: some View {
        let total = store.mustDoTotalCount(for: selectedDate)
        let completed = store.mustDoCompletedCount(for: selectedDate)
        let isGoodDay = store.isGoodDay(for: selectedDate)
        let streak = store.currentGoodDayStreak()

        return Group {
            if total > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if isGoodDay {
                            Text("All must-dos done!")
                                .font(.custom("PatrickHand-Regular", size: 15))
                                .foregroundStyle(JournalTheme.Colors.successGreen)
                        } else {
                            Text("\(completed)/\(total) must-dos complete")
                                .font(.custom("PatrickHand-Regular", size: 15))
                                .foregroundStyle(JournalTheme.Colors.amber)
                        }

                        if streak > 0 {
                            Text("\(streak) day streak · keep it going!")
                                .font(.custom("PatrickHand-Regular", size: 12))
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                        }
                    }

                    Spacer()

                    Text("🔥")
                        .font(.custom("PatrickHand-Regular", size: 28))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isGoodDay
                            ? JournalTheme.Colors.successGreen.opacity(0.12)
                            : JournalTheme.Colors.amber.opacity(0.12))
                )
                .padding(.horizontal, contentPadding)
                .padding(.top, 8)
                .animation(.easeInOut(duration: 0.3), value: isGoodDay)
                .animation(.easeInOut(duration: 0.3), value: completed)
            }
        }
    }

    // MARK: - Block Status Banner

    @ViewBuilder
    private var blockStatusBanner: some View {
        let count = blockSettings.selectedCount
        if blockSettings.isEnabled && count > 0 {
            Button {
                showingBlockSetup = true
            } label: {
                HStack(spacing: 8) {
                    Text("🔒")
                        .font(.custom("PatrickHand-Regular", size: 14))

                    Text("\(count) app\(count == 1 ? "" : "s") blocked")
                        .font(.custom("PatrickHand-Regular", size: 13))
                        .foregroundStyle(JournalTheme.Colors.inkBlack.opacity(0.7))

                    if blockSettings.isCurrentlyActive {
                        Text("· until \(blockSettings.endTimeString)")
                            .font(.custom("PatrickHand-Regular", size: 13))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.custom("PatrickHand-Regular", size: 10))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(JournalTheme.Colors.paperLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(JournalTheme.Colors.lineMedium.opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, contentPadding)
            .padding(.top, 6)
        }
    }

    // MARK: - Section Header Helper

    private func sectionHeader(_ title: String, color: Color, badge: Int? = nil) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(JournalTheme.Fonts.sectionHeader())
                .foregroundStyle(color)
                .tracking(2)

            if let badge = badge, badge > 0 {
                Text("\(badge)")
                    .font(.custom("PatrickHand-Regular", size: 10))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(color))
            }

            Spacer()
        }
        .padding(.horizontal, contentPadding)
        .padding(.bottom, 4)
    }

    // MARK: - Must Do Section

    @ViewBuilder
    private var mustDoSection: some View {
        let uncompletedMustDos = store.uncompletedStandaloneMustDoHabits(for: selectedDate)
        let uncompletedGroups = store.mustDoGroups.filter { !$0.isSatisfied(habits: store.habits, for: selectedDate) }

        VStack(spacing: 0) {
            if !uncompletedMustDos.isEmpty || !uncompletedGroups.isEmpty {
                sectionHeader("★ MUST-DOS:", color: JournalTheme.Colors.amber)

                // Standalone must-do habits (uncompleted only)
                ForEach(uncompletedMustDos) { habit in
                    if isSelectingForGroup {
                        SelectableHabitRow(
                            habit: habit,
                            isSelected: selectedHabitIdsForGroup.contains(habit.id),
                            lineHeight: lineHeight
                        ) {
                            toggleGroupSelection(habit)
                        }
                    } else {
                        HabitLinedRow(
                            habit: habit,
                            isCompleted: habit.isCompleted(for: selectedDate),
                            lineHeight: lineHeight,
                            onComplete: {
                                store.setCompletion(for: habit, completed: true, on: selectedDate)
                                handleCompletionOverlay(for: habit)
                            },
                            onUncomplete: { store.setCompletion(for: habit, completed: false, on: selectedDate) },
                            onArchive: { store.archiveHabit(habit) },
                            onTap: { selectedHabit = habit },
                            onLongPress: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isSelectingForGroup = true
                                    selectedHabitIdsForGroup = [habit.id]
                                }
                            }
                        )
                        .contextMenu {
                            Button {
                                selectedHabit = habit
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isSelectingForGroup = true
                                    selectedHabitIdsForGroup = [habit.id]
                                }
                            } label: {
                                Label("Create Group", systemImage: "folder.badge.plus")
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: uncompletedMustDos.count)

                // Must-do groups with their habits (uncompleted only)
                ForEach(uncompletedGroups) { group in
                    VStack(spacing: 0) {
                        GroupLinedRow(
                            group: group,
                            habits: store.habits(for: group),
                            lineHeight: lineHeight,
                            store: store,
                            selectedDate: selectedDate,
                            onSelectHabit: { selectedHabit = $0 },
                            onDelete: { store.deleteGroup(group) },
                            onLastHabitDeleted: {
                                groupToDeleteAfterHabit = group
                                showDeleteGroupAlert = true
                            },
                            onLongPress: { selectedGroup = group },
                            onHobbyComplete: { habit in
                                handleCompletionOverlay(for: habit)
                            },
                            onSubHabitLongPress: { habit in
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isSelectingForGroup = true
                                    selectedHabitIdsForGroup = [habit.id]
                                }
                            },
                            onSwipeComplete: {
                                let uncompleted = store.habits(for: group).filter { !$0.isCompleted(for: selectedDate) }
                                if uncompleted.count == 1, let only = uncompleted.first {
                                    // Only one uncompleted sub-habit — complete it directly
                                    store.setCompletion(for: only, completed: true, on: selectedDate)
                                    store.recordSelectedOption(for: only, option: only.name, on: selectedDate)
                                    handleCompletionOverlay(for: only)
                                } else {
                                    subHabitPickerGroup = group
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showSubHabitPicker = true
                                    }
                                }
                            }
                        )

                        // First-time group callout
                        if showGroupCallout && group.id == store.mustDoGroups.first?.id {
                            groupCalloutView
                        }
                    }
                }
            }

            // "+ New must-do" button at the end of the section
            newMustDoButton
        }
    }

    /// Lightbulb callout explaining habit groups — shown once when user first creates a group
    private var groupCalloutView: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("💡")
                .font(.custom("PatrickHand-Regular", size: 20))

            VStack(alignment: .leading, spacing: 4) {
                Text("Habit groups")
                    .font(JournalTheme.Fonts.handwritten(size: 15))
                    .fontWeight(.semibold)
                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                Text("Some habits have multiple ways to do them. \"Exercise\" might be gym, swimming, or a run. Create a group and add your options as sub-habits. Complete any one to tick off the group for the day.")
                    .font(JournalTheme.Fonts.habitCriteria())
                    .foregroundStyle(JournalTheme.Colors.sectionHeader)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    showGroupCallout = false
                    hasSeenGroupCallout = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.custom("PatrickHand-Regular", size: 12))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JournalTheme.Colors.amber.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(JournalTheme.Colors.amber.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, contentPadding)
        .padding(.top, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// Dashed "New must-do" button at the end of the must-do section
    private var newMustDoButton: some View {
        Button {
            showingAddMustDo = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.custom("PatrickHand-Regular", size: 13))
                    .foregroundStyle(JournalTheme.Colors.amber)

                Text("New must-do")
                    .font(.custom("PatrickHand-Regular", size: 14))
                    .foregroundStyle(JournalTheme.Colors.amber)

                Spacer()
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        JournalTheme.Colors.amber.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, contentPadding)
        .padding(.top, 8)
    }

    // MARK: - Nice To Do Section (uncompleted only)

    @ViewBuilder
    private var niceToDoSection: some View {
        let uncompleted = store.uncompletedNiceToDoHabits(for: selectedDate)

        VStack(spacing: 0) {
            if !uncompleted.isEmpty {
                sectionHeader("NICE-TO-DOS:", color: JournalTheme.Colors.sectionHeader)

                ForEach(uncompleted) { habit in
                    if isSelectingForGroup {
                        SelectableHabitRow(
                            habit: habit,
                            isSelected: selectedHabitIdsForGroup.contains(habit.id),
                            lineHeight: lineHeight
                        ) {
                            toggleGroupSelection(habit)
                        }
                    } else {
                        HabitLinedRow(
                            habit: habit,
                            isCompleted: false,
                            lineHeight: lineHeight,
                            onComplete: {
                                store.setCompletion(for: habit, completed: true, on: selectedDate)
                                handleCompletionOverlay(for: habit)
                            },
                            onUncomplete: { store.setCompletion(for: habit, completed: false, on: selectedDate) },
                            onArchive: { store.archiveHabit(habit) },
                            onTap: { selectedHabit = habit },
                            onLongPress: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isSelectingForGroup = true
                                    selectedHabitIdsForGroup = [habit.id]
                                }
                            }
                        )
                        .contextMenu {
                            Button {
                                selectedHabit = habit
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isSelectingForGroup = true
                                    selectedHabitIdsForGroup = [habit.id]
                                }
                            } label: {
                                Label("Create Group", systemImage: "folder.badge.plus")
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: uncompleted.count)
            }

            // "+ New nice-to-do" button at the end of the section
            newNiceToDoButton
        }
    }

    /// Dashed "New nice-to-do" button at the end of the nice-to-do section
    private var newNiceToDoButton: some View {
        Button {
            showingAddNiceToDo = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.custom("PatrickHand-Regular", size: 13))
                    .foregroundStyle(JournalTheme.Colors.navy)

                Text("New nice-to-do")
                    .font(.custom("PatrickHand-Regular", size: 14))
                    .foregroundStyle(JournalTheme.Colors.navy)

                Spacer()
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        JournalTheme.Colors.navy.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, contentPadding)
        .padding(.top, 8)
    }

    // MARK: - Time of Day Sections

    /// Anytime section - habits without any schedule times
    @ViewBuilder
    private var anytimeSection: some View {
        let anytimeHabits = store.anytimeHabits(for: selectedDate)

        if !anytimeHabits.isEmpty {
            VStack(spacing: 0) {
                sectionHeader("⏰ ANYTIME", color: JournalTheme.Colors.sectionHeader)

                ForEach(anytimeHabits) { habit in
                    TimeSlotHabitRow(
                        habit: habit,
                        groupName: store.groupName(for: habit),
                        isCompleted: habit.isCompleted(for: selectedDate),
                        lineHeight: lineHeight,
                        onComplete: {
                            store.setCompletion(for: habit, completed: true, on: selectedDate)
                            handleCompletionOverlay(for: habit)
                        },
                        onUncomplete: { store.setCompletion(for: habit, completed: false, on: selectedDate) },
                        onTap: { selectedHabit = habit },
                        onLongPress: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isSelectingForGroup = true
                                selectedHabitIdsForGroup = [habit.id]
                            }
                        }
                    )
                }
            }
        }
    }

    /// Section for a specific time slot
    @ViewBuilder
    private func timeSlotSection(for slot: TimeSlot) -> some View {
        let slotHabits = store.habitsForTimeSlot(slot, on: selectedDate)

        if !slotHabits.isEmpty {
            VStack(spacing: 0) {
                sectionHeader("\(slot.emoji) \(slot.displayName)", color: JournalTheme.Colors.sectionHeader)

                ForEach(slotHabits) { habit in
                    TimeSlotHabitRow(
                        habit: habit,
                        groupName: store.groupName(for: habit),
                        isCompleted: habit.isCompleted(for: selectedDate),
                        lineHeight: lineHeight,
                        onComplete: {
                            store.setCompletion(for: habit, completed: true, on: selectedDate)
                            handleCompletionOverlay(for: habit)
                        },
                        onUncomplete: { store.setCompletion(for: habit, completed: false, on: selectedDate) },
                        onTap: { selectedHabit = habit },
                        onLongPress: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isSelectingForGroup = true
                                selectedHabitIdsForGroup = [habit.id]
                            }
                        }
                    )
                }
            }
        }
    }

    /// Dashed "New today task" button — shown at bottom of done or today-only section
    private var newTodayTaskButton: some View {
        Button {
            showingAddTodayTask = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.custom("PatrickHand-Regular", size: 13))
                    .foregroundStyle(JournalTheme.Colors.teal)

                Text("New today task")
                    .font(.custom("PatrickHand-Regular", size: 14))
                    .foregroundStyle(JournalTheme.Colors.teal)

                Spacer()
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        JournalTheme.Colors.teal.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, contentPadding)
        .padding(.top, 8)
    }

    // MARK: - Today Only Section (uncompleted tasks only)

    @ViewBuilder
    private var todayOnlySection: some View {
        if !store.todayVisibleTasks.isEmpty {
            VStack(spacing: 0) {
                sectionHeader("◇ TODAY ONLY", color: JournalTheme.Colors.teal, badge: store.todayVisibleTasks.count)

                ForEach(store.todayVisibleTasks) { task in
                    TaskLinedRow(
                        habit: task,
                        isCompleted: false,
                        lineHeight: lineHeight,
                        onComplete: {
                            store.setCompletion(for: task, completed: true, on: selectedDate)
                        },
                        onUncomplete: { },
                        onDelete: { store.deleteHabit(task) }
                    )
                }
                .animation(.easeInOut(duration: 0.25), value: store.todayVisibleTasks.count)

                // Show "New today task" button under today-only when there are uncompleted tasks
                newTodayTaskButton
            }
        }
    }

    // MARK: - Don't Do Section

    @ViewBuilder
    private var dontDoSection: some View {
        VStack(spacing: 0) {
            if !store.negativeHabits.isEmpty {
                sectionHeader("DON'T-DOS:", color: JournalTheme.Colors.negativeRedDark)

                ForEach(store.negativeHabits) { habit in
                    if isSelectingForGroup {
                        SelectableHabitRow(
                            habit: habit,
                            isSelected: selectedHabitIdsForGroup.contains(habit.id),
                            lineHeight: lineHeight
                        ) {
                            toggleGroupSelection(habit)
                        }
                    } else {
                        let isScreenTimeSlipped = habit.isScreenTimeLinked && habit.isCompleted(for: selectedDate)
                        let isAppBlockSlipped = habit.triggersAppBlockSlip && blockSettings.areNegativeHabitsLockedToday && habit.isCompleted(for: selectedDate)
                        let isSlipLocked = isScreenTimeSlipped || isAppBlockSlipped

                        NegativeHabitLinedRow(
                            habit: habit,
                            isCompleted: habit.isCompleted(for: selectedDate),
                            daysSince: store.calculateDaysSinceLastDone(for: habit),
                            lineHeight: lineHeight,
                            onComplete: { store.setCompletion(for: habit, completed: true, on: selectedDate) },
                            onUncomplete: {
                                // Only allow undo if not locked
                                if !isSlipLocked {
                                    store.setCompletion(for: habit, completed: false, on: selectedDate)
                                }
                                // If locked, do nothing - lock icon already indicates it can't be undone
                            },
                            onArchive: { store.archiveHabit(habit) },
                            onTap: { selectedHabit = habit },
                            onLongPress: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isSelectingForGroup = true
                                    selectedHabitIdsForGroup = [habit.id]
                                }
                            },
                            isLocked: isSlipLocked
                        )
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: store.negativeHabits.count)
            }

            // "+ New don't-do" button at the end of the section
            newDontDoButton
        }
    }

    /// Dashed "New don't-do" button at the end of the don't-do section
    private var newDontDoButton: some View {
        Button {
            showingAddDontDo = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.custom("PatrickHand-Regular", size: 13))
                    .foregroundStyle(JournalTheme.Colors.negativeRedDark)

                Text("New don't-do")
                    .font(.custom("PatrickHand-Regular", size: 14))
                    .foregroundStyle(JournalTheme.Colors.negativeRedDark)

                Spacer()
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        JournalTheme.Colors.negativeRedDark.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, contentPadding)
        .padding(.top, 8)
    }

    // MARK: - Done Section (completed nice-to-do + completed tasks)

    @ViewBuilder
    private var doneSection: some View {
        let completedMustDo = store.completedStandaloneMustDoHabits(for: selectedDate)
        let completedNiceToDo = store.completedNiceToDoHabits(for: selectedDate)
        let completedTasks = store.todayCompletedTasks

        if !completedMustDo.isEmpty || !completedNiceToDo.isEmpty || !completedTasks.isEmpty {
            VStack(spacing: 0) {
                sectionHeader("DONE ✓", color: JournalTheme.Colors.completedGray)

                // Completed must-do habits
                ForEach(completedMustDo) { habit in
                    HabitLinedRow(
                        habit: habit,
                        isCompleted: true,
                        lineHeight: lineHeight,
                        onComplete: { },
                        onUncomplete: { store.setCompletion(for: habit, completed: false, on: selectedDate) },
                        onArchive: { store.archiveHabit(habit) },
                        onTap: { store.setCompletion(for: habit, completed: false, on: selectedDate) },
                        onLongPress: { selectedHabit = habit }
                    )
                    .opacity(0.6)
                }

                // Completed nice-to-do habits
                ForEach(completedNiceToDo) { habit in
                    HabitLinedRow(
                        habit: habit,
                        isCompleted: true,
                        lineHeight: lineHeight,
                        onComplete: { },
                        onUncomplete: { store.setCompletion(for: habit, completed: false, on: selectedDate) },
                        onArchive: { store.archiveHabit(habit) },
                        onTap: { store.setCompletion(for: habit, completed: false, on: selectedDate) },
                        onLongPress: { selectedHabit = habit }
                    )
                    .opacity(0.6)
                }

                // Completed tasks
                ForEach(completedTasks) { task in
                    TaskLinedRow(
                        habit: task,
                        isCompleted: true,
                        lineHeight: lineHeight,
                        onComplete: { },
                        onUncomplete: {
                            store.setCompletion(for: task, completed: false, on: selectedDate)
                        },
                        onDelete: { store.deleteHabit(task) }
                    )
                    .opacity(0.6)
                }

                // "New today task" button at bottom of done section only when all tasks are done (today-only is empty)
                if !hasTodayOnlyContent && !store.todayCompletedTasks.isEmpty {
                    newTodayTaskButton
                }
            }
        }
    }

    // MARK: - Reflection Button

    @ViewBuilder
    private var reflectionButton: some View {
        let hasNote = store.endOfDayNote(for: selectedDate) != nil

        Button {
            showingReflection = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: hasNote ? "book.fill" : "book")
                    .font(.custom("PatrickHand-Regular", size: 16))
                    .foregroundStyle(JournalTheme.Colors.inkBlue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(hasNote ? "View Today's Reflection" : "Write Today's Reflection")
                        .font(.custom("PatrickHand-Regular", size: 14))
                        .foregroundStyle(JournalTheme.Colors.inkBlack)

                    if !hasNote {
                        Text("How was your day?")
                            .font(JournalTheme.Fonts.habitCriteria())
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    } else if let note = store.endOfDayNote(for: selectedDate) {
                        Text("\(note.fulfillmentScore)/10 — \(note.note.isEmpty ? "No note" : String(note.note.prefix(30)))")
                            .font(JournalTheme.Fonts.habitCriteria())
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.custom("PatrickHand-Regular", size: 12))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(JournalTheme.Colors.inkBlue.opacity(0.06))
                    .strokeBorder(JournalTheme.Colors.inkBlue.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, contentPadding)
    }

    // MARK: - Group Selection Helpers

    private func toggleGroupSelection(_ habit: Habit) {
        Feedback.selection()

        if selectedHabitIdsForGroup.contains(habit.id) {
            selectedHabitIdsForGroup.remove(habit.id)

            // Exit selection mode if no habits are selected
            if selectedHabitIdsForGroup.isEmpty {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSelectingForGroup = false
                }
            }
        } else {
            selectedHabitIdsForGroup.insert(habit.id)
        }
    }

}

/// A row used during group selection mode — tappable with selection indicator
struct SelectableHabitRow: View {
    let habit: Habit
    let isSelected: Bool
    let lineHeight: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isSelected ? JournalTheme.Colors.inkBlue : JournalTheme.Colors.completedGray,
                            lineWidth: 1.5
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? JournalTheme.Colors.inkBlue : Color.clear)
                        )
                        .overlay {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.custom("PatrickHand-Regular", size: 11))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 20, height: 20)
                }

                Text(habit.name)
                    .font(JournalTheme.Fonts.habitName())
                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                if let criteria = habit.criteriaDisplayString {
                    Text("(\(criteria))")
                        .font(JournalTheme.Fonts.habitCriteria())
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }

                Spacer()

                // Tier badge
                Text(habit.tier == .mustDo ? "Must-do" : "Nice-to-do")
                    .font(.custom("PatrickHand-Regular", size: 10))
                    .foregroundStyle(habit.tier == .mustDo ? JournalTheme.Colors.amber : JournalTheme.Colors.navy)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill((habit.tier == .mustDo ? JournalTheme.Colors.amber : JournalTheme.Colors.navy).opacity(0.12))
                    )
            }
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .background(
                isSelected
                    ? JournalTheme.Colors.inkBlue.opacity(0.06)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
    }
}

/// A row that aligns to the paper lines
struct LinedRow<Content: View>: View {
    let height: CGFloat
    @ViewBuilder let content: () -> Content



    var body: some View {
        HStack(spacing: 0) {
            content()
        }
        .frame(height: height, alignment: .bottomLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }
}

/// A habit row with swipe-to-strikethrough gesture and swipe-left-to-archive
struct HabitLinedRow: View {
    let habit: Habit
    let isCompleted: Bool
    let lineHeight: CGFloat
    let onComplete: () -> Void
    let onUncomplete: () -> Void
    let onArchive: () -> Void
    let onTap: () -> Void
    let onLongPress: () -> Void

    // Swipe gesture state
    @State private var strikethroughProgress: CGFloat
    @State private var isDragging: Bool = false
    @State private var hasPassedThreshold: Bool = false
    @State private var textWidth: CGFloat = 0
    @State private var rowWidth: CGFloat = 0

    // Archive gesture state
    @State private var archiveOffset: CGFloat = 0
    @State private var hasPassedArchiveThreshold: Bool = false

    // Auto-reset timer for incomplete gestures
    @State private var resetTask: Task<Void, Never>? = nil

    // Constants
    private let completionThreshold: CGFloat = 0.3
    private let archiveDistanceThreshold: CGFloat = 150 // Fixed pixel distance for archive


    init(habit: Habit, isCompleted: Bool, lineHeight: CGFloat,
         onComplete: @escaping () -> Void,
         onUncomplete: @escaping () -> Void,
         onArchive: @escaping () -> Void,
         onTap: @escaping () -> Void,
         onLongPress: @escaping () -> Void) {
        self.habit = habit
        self.isCompleted = isCompleted
        self.lineHeight = lineHeight
        self.onComplete = onComplete
        self.onUncomplete = onUncomplete
        self.onArchive = onArchive
        self.onTap = onTap
        self.onLongPress = onLongPress
        // Initialize progress based on completion state
        self._strikethroughProgress = State(initialValue: isCompleted ? 1.0 : 0.0)
        self._hasPassedThreshold = State(initialValue: isCompleted)
    }

    // Computed property to determine if visually completed
    private var isVisuallyCompleted: Bool {
        strikethroughProgress >= completionThreshold
    }

    // Archive progress as percentage (0 to 1) for visual feedback
    private var archiveProgress: CGFloat {
        guard archiveOffset < 0 else { return 0 }
        return min(1, abs(archiveOffset) / archiveDistanceThreshold)
    }

    var body: some View {
        ZStack {
            // Archive background (orange, only shown when swiping left)
            if archiveOffset < 0 {
                HStack {
                    Spacer()
                    ZStack {
                        Color.orange

                        Image(systemName: "archivebox")
                            .font(.custom("PatrickHand-Regular", size: 18))
                            .foregroundStyle(.white)
                            .opacity(archiveProgress > 0.3 ? 1 : archiveProgress * 3)
                    }
                    .frame(width: abs(archiveOffset))
                }
            }

            // Main content
            HStack(spacing: 12) {
                // Bullet dot
                Circle()
                    .fill(isVisuallyCompleted
                        ? JournalTheme.Colors.completedGray
                        : JournalTheme.Colors.inkBlack)
                    .frame(width: 6, height: 6)

                // Habit text with strikethrough overlay
                HStack(spacing: 6) {
                    Text(habit.name)
                        .font(JournalTheme.Fonts.habitName())
                        .foregroundStyle(
                            isVisuallyCompleted
                                ? JournalTheme.Colors.completedGray
                                : JournalTheme.Colors.inkBlack
                        )

                    if let criteria = habit.criteriaDisplayString {
                        Text("(\(criteria))")
                            .font(JournalTheme.Fonts.habitCriteria())
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }
                }
                .background(
                    GeometryReader { textGeometry in
                        Color.clear
                            .onAppear {
                                textWidth = textGeometry.size.width
                            }
                            .onChange(of: textGeometry.size.width) { _, newWidth in
                                textWidth = newWidth
                            }
                    }
                )
                .overlay(alignment: .leading) {
                    // Always show the strikethrough overlay, let the Canvas decide visibility
                    StrikethroughLine(
                        width: textWidth > 0 ? textWidth : 200, // Fallback width
                        color: JournalTheme.Colors.inkBlue,
                        progress: $strikethroughProgress
                    )
                }

                Spacer()
            }
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .background(
                GeometryReader { rowGeometry in
                    Color.clear
                        .onAppear { rowWidth = rowGeometry.size.width }
                        .onChange(of: rowGeometry.size.width) { _, w in rowWidth = w }
                }
            )
            .offset(x: archiveOffset)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        // Unified gesture on full row (right = complete, left = archive)
        .gesture(unifiedDragGesture())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    Feedback.longPress()
                    onLongPress()
                }
        )
        .onTapGesture {
            // Tap to open edit view
            Feedback.selection()
            onTap()
        }
        .onChange(of: isCompleted) { _, newValue in
            // Sync with external state changes (only when not dragging)
            if !isDragging {
                withAnimation(JournalTheme.Animations.strikethrough) {
                    strikethroughProgress = newValue ? 1.0 : 0.0
                    hasPassedThreshold = newValue
                }
            }
        }
        .onChange(of: isDragging) { _, newValue in
            if !newValue {
                // Dragging ended - start reset timer
                resetTask?.cancel()
                resetTask = Task {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    if !Task.isCancelled {
                        await MainActor.run {
                            // Reset if still in incomplete state
                            if !isCompleted && strikethroughProgress > 0 && strikethroughProgress < 1 {
                                withAnimation(JournalTheme.Animations.strikethrough) {
                                    strikethroughProgress = 0
                                    hasPassedThreshold = false
                                }
                            }
                            if archiveOffset != 0 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    archiveOffset = 0
                                    hasPassedArchiveThreshold = false
                                }
                            }
                        }
                    }
                }
            } else {
                // Dragging started - cancel any pending reset
                resetTask?.cancel()
            }
        }
    }

    // Unified drag gesture — right swipe = complete, left swipe = archive
    private func unifiedDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                let translation = value.translation.width

                guard horizontal > vertical else { return }

                isDragging = true

                if translation > 0 {
                    // Right swipe — completion
                    // Reset archive state if switching direction
                    if archiveOffset < 0 {
                        archiveOffset = 0
                    }

                    Feedback.startSwiping()

                    if !isCompleted {
                        let hitbox = rowWidth > 0 ? rowWidth : 300
                        let forwardProgress = translation / hitbox
                        strikethroughProgress = max(0, min(1, forwardProgress))

                        let currentlyPastThreshold = strikethroughProgress >= completionThreshold
                        if currentlyPastThreshold != hasPassedThreshold {
                            hasPassedThreshold = currentlyPastThreshold
                            Feedback.thresholdCrossed()
                        }
                    }
                } else {
                    // Left swipe — archive
                    // Reset completion progress if switching direction
                    if strikethroughProgress > 0 && !isCompleted {
                        strikethroughProgress = 0
                    }

                    archiveOffset = translation

                    let currentlyPastArchive = abs(translation) >= archiveDistanceThreshold
                    if currentlyPastArchive != hasPassedArchiveThreshold {
                        hasPassedArchiveThreshold = currentlyPastArchive
                        Feedback.thresholdCrossed()
                    }
                }
            }
            .onEnded { value in
                isDragging = false
                let translation = value.translation.width

                if translation > 0 {
                    // Right swipe ended — completion
                    if !isCompleted {
                        if strikethroughProgress >= completionThreshold {
                            withAnimation(JournalTheme.Animations.strikethrough) {
                                strikethroughProgress = 1.0
                            }
                            Feedback.swipeCompleted()
                            onComplete()
                            hasPassedThreshold = true
                        } else {
                            withAnimation(JournalTheme.Animations.strikethrough) {
                                strikethroughProgress = 0
                            }
                            Feedback.swipeCancelled()
                            hasPassedThreshold = false
                        }
                    } else {
                        Feedback.stopSwiping()
                    }
                } else {
                    // Left swipe ended — archive
                    if abs(translation) >= archiveDistanceThreshold {
                        Feedback.archive()
                        archiveOffset = 0
                        withAnimation(.easeOut(duration: 0.25)) {
                            onArchive()
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            archiveOffset = 0
                        }
                    }
                    hasPassedArchiveThreshold = false
                }
            }
    }
}

/// A negative habit row showing "X days" streak and red slip indicator
struct NegativeHabitLinedRow: View {
    let habit: Habit
    let isCompleted: Bool // "completed" means slipped today
    let daysSince: Int
    let lineHeight: CGFloat
    let onComplete: () -> Void // Mark as slipped
    let onUncomplete: () -> Void // Undo slip
    let onArchive: () -> Void
    let onTap: () -> Void
    let onLongPress: () -> Void
    var isLocked: Bool = false // When true, slip cannot be undone (auto-slipped via app blocker)

    // Archive gesture state
    @State private var archiveOffset: CGFloat = 0
    @State private var hasPassedArchiveThreshold: Bool = false
    @State private var isDragging: Bool = false
    @State private var resetTask: Task<Void, Never>? = nil

    private let archiveDistanceThreshold: CGFloat = 150


    private var archiveProgress: CGFloat {
        guard archiveOffset < 0 else { return 0 }
        return min(1, abs(archiveOffset) / archiveDistanceThreshold)
    }

    var body: some View {
        ZStack {
            // Archive background (orange, only shown when swiping left)
            if archiveOffset < 0 {
                HStack {
                    Spacer()
                    ZStack {
                        Color.orange

                        Image(systemName: "archivebox")
                            .font(.custom("PatrickHand-Regular", size: 18))
                            .foregroundStyle(.white)
                            .opacity(archiveProgress > 0.3 ? 1 : archiveProgress * 3)
                    }
                    .frame(width: abs(archiveOffset))
                }
            }

            // Main content
            HStack(spacing: 12) {
                // Bullet dot
                Circle()
                    .fill(isCompleted
                        ? JournalTheme.Colors.negativeRedDark
                        : JournalTheme.Colors.inkBlack)
                    .frame(width: 6, height: 6)

                // Habit name
                Text(habit.name)
                    .font(JournalTheme.Fonts.habitName())
                    .foregroundStyle(
                        isCompleted
                            ? JournalTheme.Colors.negativeRedDark
                            : JournalTheme.Colors.inkBlack
                    )

                if let criteria = habit.criteriaDisplayString {
                    Text("(\(criteria))")
                        .font(JournalTheme.Fonts.habitCriteria())
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }

                Spacer()

                // Days since / slipped pill badge
                if !isCompleted {
                    Text(daysSince < 0 ? "New" : "\(daysSince) days")
                        .font(.custom("PatrickHand-Regular", size: 10))
                        .foregroundStyle(JournalTheme.Colors.goodDayGreenDark)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(JournalTheme.Colors.goodDayGreenDark.opacity(0.12))
                        )
                } else {
                    HStack(spacing: 4) {
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.custom("PatrickHand-Regular", size: 8))
                                .foregroundStyle(JournalTheme.Colors.negativeRedDark)
                        }
                        Text("Slipped")
                            .font(.custom("PatrickHand-Regular", size: 10))
                            .foregroundStyle(JournalTheme.Colors.negativeRedDark)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(JournalTheme.Colors.negativeRedDark.opacity(0.12))
                    )
                }
            }
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .background(Color.clear)
            .offset(x: archiveOffset)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .gesture(archiveGesture())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    Feedback.longPress()
                    onLongPress()
                }
        )
        .onTapGesture {
            // Tap to open edit view
            Feedback.selection()
            onTap()
        }
        .onChange(of: isDragging) { _, newValue in
            if !newValue {
                resetTask?.cancel()
                resetTask = Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if !Task.isCancelled {
                        await MainActor.run {
                            if archiveOffset != 0 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    archiveOffset = 0
                                    hasPassedArchiveThreshold = false
                                }
                            }
                        }
                    }
                }
            } else {
                resetTask?.cancel()
            }
        }
    }

    private func archiveGesture() -> some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                let translation = value.translation.width

                guard horizontal > vertical, translation < 0 else { return }

                isDragging = true
                archiveOffset = translation

                let currentlyPastArchive = abs(translation) >= archiveDistanceThreshold
                if currentlyPastArchive != hasPassedArchiveThreshold {
                    hasPassedArchiveThreshold = currentlyPastArchive
                    Feedback.thresholdCrossed()
                }
            }
            .onEnded { value in
                isDragging = false
                let translation = value.translation.width

                guard translation < 0 else { return }

                if abs(translation) >= archiveDistanceThreshold {
                    Feedback.archive()
                    archiveOffset = 0
                    withAnimation(.easeOut(duration: 0.25)) {
                        onArchive()
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        archiveOffset = 0
                    }
                }
                hasPassedArchiveThreshold = false
            }
    }
}

/// A one-off task row with teal bullet dot, swipe-to-strikethrough, and swipe-left-to-delete
struct TaskLinedRow: View {
    let habit: Habit
    let isCompleted: Bool
    let lineHeight: CGFloat
    let onComplete: () -> Void
    let onUncomplete: () -> Void
    let onDelete: () -> Void

    // Swipe-to-complete gesture state
    @State private var strikethroughProgress: CGFloat
    @State private var isDragging: Bool = false
    @State private var hasPassedThreshold: Bool = false
    @State private var textWidth: CGFloat = 0
    @State private var rowWidth: CGFloat = 0

    // Delete gesture state (swipe left)
    @State private var deleteOffset: CGFloat = 0
    @State private var hasPassedDeleteThreshold: Bool = false

    // Auto-reset timer
    @State private var resetTask: Task<Void, Never>? = nil

    // Constants
    private let completionThreshold: CGFloat = 0.3
    private let deleteDistanceThreshold: CGFloat = 150


    init(habit: Habit, isCompleted: Bool, lineHeight: CGFloat,
         onComplete: @escaping () -> Void,
         onUncomplete: @escaping () -> Void,
         onDelete: @escaping () -> Void) {
        self.habit = habit
        self.isCompleted = isCompleted
        self.lineHeight = lineHeight
        self.onComplete = onComplete
        self.onUncomplete = onUncomplete
        self.onDelete = onDelete
        self._strikethroughProgress = State(initialValue: isCompleted ? 1.0 : 0.0)
        self._hasPassedThreshold = State(initialValue: isCompleted)
    }

    private var isVisuallyCompleted: Bool {
        strikethroughProgress >= completionThreshold
    }

    private var deleteProgress: CGFloat {
        guard deleteOffset < 0 else { return 0 }
        return min(1, abs(deleteOffset) / deleteDistanceThreshold)
    }

    var body: some View {
        ZStack {
            // Delete background (coral, only shown when swiping left)
            if deleteOffset < 0 {
                HStack {
                    Spacer()
                    ZStack {
                        JournalTheme.Colors.coral

                        Image(systemName: "trash")
                            .font(.custom("PatrickHand-Regular", size: 18))
                            .foregroundStyle(.white)
                            .opacity(deleteProgress > 0.3 ? 1 : deleteProgress * 3)
                    }
                    .frame(width: abs(deleteOffset))
                }
            }

            // Main content
            HStack(spacing: 12) {
                // Bullet dot (teal to distinguish tasks)
                Circle()
                    .fill(isVisuallyCompleted
                        ? JournalTheme.Colors.completedGray
                        : JournalTheme.Colors.teal)
                    .frame(width: 6, height: 6)

                // Task text with strikethrough overlay
                HStack(spacing: 6) {
                    Text(habit.name)
                        .font(JournalTheme.Fonts.habitName())
                        .foregroundStyle(
                            isVisuallyCompleted
                                ? JournalTheme.Colors.completedGray
                                : JournalTheme.Colors.inkBlack
                        )
                }
                .background(
                    GeometryReader { textGeometry in
                        Color.clear
                            .onAppear { textWidth = textGeometry.size.width }
                            .onChange(of: textGeometry.size.width) { _, newWidth in
                                textWidth = newWidth
                            }
                    }
                )
                .overlay(alignment: .leading) {
                    StrikethroughLine(
                        width: textWidth > 0 ? textWidth : 200,
                        color: JournalTheme.Colors.teal,
                        progress: $strikethroughProgress
                    )
                }

                Spacer()

                // TODAY badge
                if !isVisuallyCompleted {
                    Text("TODAY")
                        .font(.custom("PatrickHand-Regular", size: 9))
                        .foregroundStyle(JournalTheme.Colors.teal)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(JournalTheme.Colors.teal.opacity(0.12))
                        )
                }
            }
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .background(
                GeometryReader { rowGeometry in
                    Color.clear
                        .onAppear { rowWidth = rowGeometry.size.width }
                        .onChange(of: rowGeometry.size.width) { _, w in rowWidth = w }
                }
            )
            .offset(x: deleteOffset)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        // Unified gesture on full row (right = complete, left = delete)
        .gesture(unifiedDragGesture())
        .onTapGesture {
            // Tap to undo completion
            if isCompleted {
                withAnimation(JournalTheme.Animations.strikethrough) {
                    strikethroughProgress = 0.0
                    hasPassedThreshold = false
                }
                Feedback.undo()
                onUncomplete()
            }
        }
        .onChange(of: isCompleted) { _, newValue in
            if !isDragging {
                withAnimation(JournalTheme.Animations.strikethrough) {
                    strikethroughProgress = newValue ? 1.0 : 0.0
                    hasPassedThreshold = newValue
                }
            }
        }
        .onChange(of: isDragging) { _, newValue in
            if !newValue {
                resetTask?.cancel()
                resetTask = Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if !Task.isCancelled {
                        await MainActor.run {
                            if !isCompleted && strikethroughProgress > 0 && strikethroughProgress < 1 {
                                withAnimation(JournalTheme.Animations.strikethrough) {
                                    strikethroughProgress = 0
                                    hasPassedThreshold = false
                                }
                            }
                            if deleteOffset != 0 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    deleteOffset = 0
                                    hasPassedDeleteThreshold = false
                                }
                            }
                        }
                    }
                }
            } else {
                resetTask?.cancel()
            }
        }
    }

    // Unified drag gesture — right swipe = complete, left swipe = delete
    private func unifiedDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                let translation = value.translation.width

                guard horizontal > vertical else { return }

                isDragging = true

                if translation > 0 {
                    // Right swipe — completion
                    if deleteOffset < 0 {
                        deleteOffset = 0
                    }

                    Feedback.startSwiping()

                    if !isCompleted {
                        let hitbox = rowWidth > 0 ? rowWidth : 300
                        let forwardProgress = translation / hitbox
                        strikethroughProgress = max(0, min(1, forwardProgress))

                        let currentlyPastThreshold = strikethroughProgress >= completionThreshold
                        if currentlyPastThreshold != hasPassedThreshold {
                            hasPassedThreshold = currentlyPastThreshold
                            Feedback.thresholdCrossed()
                        }
                    }
                } else {
                    // Left swipe — delete
                    if strikethroughProgress > 0 && !isCompleted {
                        strikethroughProgress = 0
                    }

                    deleteOffset = translation

                    let currentlyPastDelete = abs(translation) >= deleteDistanceThreshold
                    if currentlyPastDelete != hasPassedDeleteThreshold {
                        hasPassedDeleteThreshold = currentlyPastDelete
                        Feedback.thresholdCrossed()
                    }
                }
            }
            .onEnded { value in
                isDragging = false
                let translation = value.translation.width

                if translation > 0 {
                    // Right swipe ended — completion
                    if !isCompleted {
                        if strikethroughProgress >= completionThreshold {
                            withAnimation(JournalTheme.Animations.strikethrough) {
                                strikethroughProgress = 1.0
                            }
                            Feedback.swipeCompleted()
                            onComplete()
                            hasPassedThreshold = true
                        } else {
                            withAnimation(JournalTheme.Animations.strikethrough) {
                                strikethroughProgress = 0
                            }
                            Feedback.swipeCancelled()
                            hasPassedThreshold = false
                        }
                    } else {
                        Feedback.stopSwiping()
                    }
                } else {
                    // Left swipe ended — delete
                    if abs(translation) >= deleteDistanceThreshold {
                        Feedback.delete()
                        deleteOffset = 0
                        withAnimation(.easeOut(duration: 0.25)) {
                            onDelete()
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            deleteOffset = 0
                        }
                    }
                    hasPassedDeleteThreshold = false
                }
            }
    }
}

/// A group row with collapsing sub-habits — completing one collapses the rest
struct GroupLinedRow: View {
    let group: HabitGroup
    let habits: [Habit]
    let lineHeight: CGFloat
    let store: HabitStore
    let selectedDate: Date
    let onSelectHabit: (Habit) -> Void
    let onDelete: () -> Void
    let onLastHabitDeleted: () -> Void
    let onLongPress: () -> Void
    var onHobbyComplete: ((Habit) -> Void)? = nil
    var onSubHabitLongPress: ((Habit) -> Void)? = nil
    var onSwipeComplete: (() -> Void)? = nil

    // Collapse state
    @State private var isCollapsed: Bool = false
    @State private var groupStrikethroughProgress: CGFloat = 0
    @State private var groupTextWidth: CGFloat = 0

    // Delete gesture state
    @State private var deleteOffset: CGFloat = 0
    @State private var hasPassedDeleteThreshold: Bool = false
    @State private var isDragging: Bool = false
    @State private var resetTask: Task<Void, Never>? = nil
    @State private var rowWidth: CGFloat = 0

    // Right-swipe complete state
    @State private var completeProgress: CGFloat = 0
    @State private var hasPassedCompleteThreshold: Bool = false

    private let deleteDistanceThreshold: CGFloat = 150
    private let completionThreshold: CGFloat = 0.3

    private var isSatisfied: Bool {
        group.isSatisfied(habits: store.habits, for: selectedDate)
    }

    /// The sub-habit that was completed (first one found)
    private var completedSubHabit: Habit? {
        habits.first { $0.isCompleted(for: selectedDate) }
    }

    private var deleteProgress: CGFloat {
        guard deleteOffset < 0 else { return 0 }
        return min(1, abs(deleteOffset) / deleteDistanceThreshold)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Group header row
            ZStack {
                // Delete background
                if deleteOffset < 0 {
                    HStack {
                        Spacer()
                        ZStack {
                            JournalTheme.Colors.negativeRedDark
                            Image(systemName: "trash")
                                .font(.custom("PatrickHand-Regular", size: 18))
                                .foregroundStyle(.white)
                                .opacity(deleteProgress > 0.3 ? 1 : deleteProgress * 3)
                        }
                        .frame(width: abs(deleteOffset))
                    }
                }

                // Group header content
                HStack(spacing: 12) {
                    // Bullet dot
                    Circle()
                        .fill(isSatisfied
                            ? JournalTheme.Colors.completedGray
                            : JournalTheme.Colors.inkBlack)
                        .frame(width: 6, height: 6)

                    // Group name with chosen sub-habit when collapsed
                    if isSatisfied, let chosen = completedSubHabit {
                        HStack(spacing: 6) {
                            Text(group.name)
                                .font(JournalTheme.Fonts.habitName())
                                .foregroundStyle(JournalTheme.Colors.completedGray)

                            Text("— \(chosen.name)")
                                .font(.custom("PatrickHand-Regular", size: 15))
                                .italic()
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                        }
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { groupTextWidth = geo.size.width }
                                    .onChange(of: geo.size.width) { _, w in groupTextWidth = w }
                            }
                        )
                        .overlay(alignment: .leading) {
                            StrikethroughLine(
                                width: groupTextWidth > 0 ? groupTextWidth : 200,
                                color: JournalTheme.Colors.inkBlue,
                                progress: $groupStrikethroughProgress
                            )
                        }
                    } else {
                        Text(group.name)
                            .font(JournalTheme.Fonts.habitName())
                            .foregroundStyle(JournalTheme.Colors.inkBlack)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear { groupTextWidth = geo.size.width }
                                        .onChange(of: geo.size.width) { _, w in groupTextWidth = w }
                                }
                            )
                            .overlay(alignment: .leading) {
                                StrikethroughLine(
                                    width: groupTextWidth > 0 ? groupTextWidth : 200,
                                    color: JournalTheme.Colors.inkBlue,
                                    progress: $completeProgress
                                )
                            }
                    }

                    Spacer()

                    // Options badge when uncompleted
                    if !isSatisfied {
                        Text("\(habits.count) options")
                            .font(.custom("PatrickHand-Regular", size: 10))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(JournalTheme.Colors.completedGray.opacity(0.12))
                            )
                    }
                }
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .background(
                    GeometryReader { rowGeometry in
                        Color.clear
                            .onAppear { rowWidth = rowGeometry.size.width }
                            .onChange(of: rowGeometry.size.width) { _, w in rowWidth = w }
                    }
                )
                .offset(x: deleteOffset)
            }
            .contentShape(Rectangle())
            .gesture(unifiedDragGesture())
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        Feedback.longPress()
                        onLongPress()
                    }
            )
            .onTapGesture {
                if isSatisfied {
                    // Tap collapsed group to expand and uncomplete
                    if let chosen = completedSubHabit {
                        store.setCompletion(for: chosen, completed: false, on: selectedDate)
                    }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isCollapsed = false
                    }
                    Feedback.undo()
                }
            }

            // Child sub-habits (shown when NOT collapsed)
            if !isCollapsed || !isSatisfied {
                ForEach(habits) { habit in
                    SubHabitRow(
                        habit: habit,
                        isCompleted: habit.isCompleted(for: selectedDate),
                        lineHeight: lineHeight,
                        onComplete: {
                            store.setCompletion(for: habit, completed: true, on: selectedDate)
                            // Record which sub-habit was chosen
                            store.recordSelectedOption(for: habit, option: habit.name, on: selectedDate)
                            // Collapse the group after completion
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isCollapsed = true
                            }
                            let hasCriteria = habit.successCriteria != nil && !(habit.successCriteria?.isEmpty ?? true)
                            if hasCriteria || habit.isHobby || habit.enableNotesPhotos {
                                onHobbyComplete?(habit)
                            }
                        },
                        onUncomplete: {
                            store.setCompletion(for: habit, completed: false, on: selectedDate)
                        },
                        onTap: { onSelectHabit(habit) },
                        onLongPress: { onSubHabitLongPress?(habit) }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSatisfied)
            }
        }
        .onAppear {
            // Initialize collapse state based on current completion
            isCollapsed = isSatisfied
            groupStrikethroughProgress = isSatisfied ? 1.0 : 0.0
        }
        .onChange(of: isSatisfied) { _, newValue in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isCollapsed = newValue
            }
            withAnimation(JournalTheme.Animations.strikethrough) {
                groupStrikethroughProgress = newValue ? 1.0 : 0.0
            }
        }
        .onChange(of: isDragging) { _, newValue in
            if !newValue {
                resetTask?.cancel()
                resetTask = Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if !Task.isCancelled {
                        await MainActor.run {
                            if deleteOffset != 0 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    deleteOffset = 0
                                    hasPassedDeleteThreshold = false
                                }
                            }
                            if completeProgress > 0 && completeProgress < 1 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    completeProgress = 0
                                    hasPassedCompleteThreshold = false
                                }
                            }
                        }
                    }
                }
            } else {
                resetTask?.cancel()
            }
        }
    }

    private func unifiedDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                let translation = value.translation.width

                guard horizontal > vertical else { return }

                isDragging = true

                if translation > 0 {
                    // Right swipe — complete group
                    if deleteOffset < 0 {
                        deleteOffset = 0
                    }

                    guard !isSatisfied else { return }

                    let hitbox = rowWidth > 0 ? rowWidth : 300
                    completeProgress = max(0, min(1, translation / hitbox))

                    let currentlyPast = completeProgress >= completionThreshold
                    if currentlyPast != hasPassedCompleteThreshold {
                        hasPassedCompleteThreshold = currentlyPast
                        Feedback.thresholdCrossed()
                    }
                } else {
                    // Left swipe — delete
                    if completeProgress > 0 {
                        completeProgress = 0
                    }

                    deleteOffset = translation

                    let currentlyPast = abs(translation) >= deleteDistanceThreshold
                    if currentlyPast != hasPassedDeleteThreshold {
                        hasPassedDeleteThreshold = currentlyPast
                        Feedback.thresholdCrossed()
                    }
                }
            }
            .onEnded { value in
                isDragging = false
                let translation = value.translation.width

                if translation > 0 {
                    // Right swipe ended — complete
                    if !isSatisfied && completeProgress >= completionThreshold {
                        Feedback.swipeCompleted()
                        withAnimation(JournalTheme.Animations.strikethrough) {
                            completeProgress = 1.0
                        }
                        // Small delay so strikethrough animates visually before overlay appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            completeProgress = 0
                            onSwipeComplete?()
                        }
                    } else {
                        withAnimation(JournalTheme.Animations.strikethrough) {
                            completeProgress = 0
                        }
                    }
                    hasPassedCompleteThreshold = false
                } else {
                    // Left swipe ended — delete
                    if abs(translation) >= deleteDistanceThreshold {
                        Feedback.delete()
                        deleteOffset = 0
                        withAnimation(.easeOut(duration: 0.25)) {
                            onDelete()
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            deleteOffset = 0
                        }
                    }
                    hasPassedDeleteThreshold = false
                }
            }
    }
}

/// A sub-habit row within a group — indented, slightly muted, with swipe-to-complete
struct SubHabitRow: View {
    let habit: Habit
    let isCompleted: Bool
    let lineHeight: CGFloat
    let onComplete: () -> Void
    let onUncomplete: () -> Void
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var strikethroughProgress: CGFloat
    @State private var isDragging: Bool = false
    @State private var hasPassedThreshold: Bool = false
    @State private var textWidth: CGFloat = 0
    @State private var resetTask: Task<Void, Never>? = nil

    private let completionThreshold: CGFloat = 0.3

    init(habit: Habit, isCompleted: Bool, lineHeight: CGFloat,
         onComplete: @escaping () -> Void,
         onUncomplete: @escaping () -> Void,
         onTap: @escaping () -> Void,
         onLongPress: @escaping () -> Void) {
        self.habit = habit
        self.isCompleted = isCompleted
        self.lineHeight = lineHeight
        self.onComplete = onComplete
        self.onUncomplete = onUncomplete
        self.onTap = onTap
        self.onLongPress = onLongPress
        self._strikethroughProgress = State(initialValue: isCompleted ? 1.0 : 0.0)
        self._hasPassedThreshold = State(initialValue: isCompleted)
    }

    private var isVisuallyCompleted: Bool {
        strikethroughProgress >= completionThreshold
    }

    var body: some View {
        HStack(spacing: 10) {
            // Bullet dot (smaller for sub-habits)
            Circle()
                .fill(isVisuallyCompleted
                    ? JournalTheme.Colors.completedGray
                    : JournalTheme.Colors.inkBlack)
                .frame(width: 5, height: 5)

            // Sub-habit text (slightly smaller, muted)
            HStack(spacing: 4) {
                Text(habit.name)
                    .font(.custom("PatrickHand-Regular", size: 15))
                    .foregroundStyle(
                        isVisuallyCompleted
                            ? JournalTheme.Colors.completedGray
                            : JournalTheme.Colors.inkBlack.opacity(0.75)
                    )
            }
            .background(
                GeometryReader { textGeometry in
                    Color.clear
                        .onAppear { textWidth = textGeometry.size.width }
                        .onChange(of: textGeometry.size.width) { _, newWidth in
                            textWidth = newWidth
                        }
                }
            )
            .overlay(alignment: .leading) {
                StrikethroughLine(
                    width: textWidth > 0 ? textWidth : 150,
                    color: JournalTheme.Colors.inkBlue.opacity(0.6),
                    progress: $strikethroughProgress
                )
            }

            Spacer()
        }
        .frame(minHeight: 38)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 48)
        .padding(.trailing, 24)
        .contentShape(Rectangle())
        .gesture(completionGesture(hitboxWidth: 300))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    Feedback.longPress()
                    onLongPress()
                }
        )
        .onTapGesture {
            // Tap to open edit view
            Feedback.selection()
            onTap()
        }
        .onChange(of: isCompleted) { _, newValue in
            if !isDragging {
                withAnimation(JournalTheme.Animations.strikethrough) {
                    strikethroughProgress = newValue ? 1.0 : 0.0
                    hasPassedThreshold = newValue
                }
            }
        }
        .onChange(of: isDragging) { _, newValue in
            if !newValue {
                resetTask?.cancel()
                resetTask = Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if !Task.isCancelled {
                        await MainActor.run {
                            if !isCompleted && strikethroughProgress > 0 && strikethroughProgress < 1 {
                                withAnimation(JournalTheme.Animations.strikethrough) {
                                    strikethroughProgress = 0
                                    hasPassedThreshold = false
                                }
                            }
                        }
                    }
                }
            } else {
                resetTask?.cancel()
            }
        }
    }

    private func completionGesture(hitboxWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                let translation = value.translation.width
                guard horizontal > vertical, translation > 0 else { return }

                // Keep swipe sound playing while finger is moving
                Feedback.startSwiping()
                isDragging = true
                if isCompleted { return }

                let forwardProgress = translation / hitboxWidth
                strikethroughProgress = max(0, min(1, forwardProgress))

                let currentlyPastThreshold = strikethroughProgress >= completionThreshold
                if currentlyPastThreshold != hasPassedThreshold {
                    hasPassedThreshold = currentlyPastThreshold
                    Feedback.thresholdCrossed()
                }
            }
            .onEnded { value in
                isDragging = false
                let translation = value.translation.width
                guard translation > 0 else {
                    Feedback.stopSwiping()
                    return
                }

                if !isCompleted {
                    if strikethroughProgress >= completionThreshold {
                        withAnimation(JournalTheme.Animations.strikethrough) {
                            strikethroughProgress = 1.0
                        }
                        Feedback.swipeCompleted()
                        onComplete()
                        hasPassedThreshold = true
                    } else {
                        withAnimation(JournalTheme.Animations.strikethrough) {
                            strikethroughProgress = 0
                        }
                        Feedback.swipeCancelled()
                        hasPassedThreshold = false
                    }
                } else {
                    Feedback.stopSwiping()
                }
            }
    }
}

// MARK: - Celebration Overlay

struct CelebrationOverlay: View {
    @Binding var isShowing: Bool
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var textOpacity: Double = 0
    @State private var textScale: Double = 0.5
    @State private var congratsScale: Double = 1.0

    var body: some View {
        ZStack {
            // White overlay to dim the background
            Color.white
                .opacity(0.7)
                .ignoresSafeArea()

            // Green overlay background
            JournalTheme.Colors.goodDayGreen
                .opacity(0.5)
                .ignoresSafeArea()

            // Confetti particles
            ForEach(confettiParticles) { particle in
                ConfettiPiece(particle: particle)
            }

            // Celebration text
            VStack(spacing: 16) {
                Text("Congratulations!")
                    .font(.custom("PatrickHand-Regular", size: 44))
                    .foregroundStyle(JournalTheme.Colors.goodDayGreenDark)
                    .scaleEffect(congratsScale)

                Text("Today was a good day!")
                    .font(.custom("PatrickHand-Regular", size: 20))
                    .foregroundStyle(JournalTheme.Colors.inkBlack.opacity(0.8))
                
                Text("Give yourself a pat on the back!")
                    .font(.custom("PatrickHand-Regular", size: 20))
                    .foregroundStyle(JournalTheme.Colors.inkBlack.opacity(0.8))

                Text("Tap anywhere to continue")
                    .font(.custom("PatrickHand-Regular", size: 14))
                    .foregroundStyle(JournalTheme.Colors.goodDayGreenDark.opacity(0.8))
                    .padding(.top, 20)
            }
            .opacity(textOpacity)
            .scaleEffect(textScale)
        }
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.3)) {
                isShowing = false
            }
        }
        .onAppear {
            // Animate text in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                textOpacity = 1
                textScale = 1
            }

            // Pulse animation for Congratulations - expand then shrink over 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    congratsScale = 1.1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        congratsScale = 1.0
                    }
                }
            }

            // Create confetti from both sides
            createConfetti()
        }
    }

    private func createConfetti() {
        let colors: [Color] = [
            JournalTheme.Colors.goodDayGreenDark,
            JournalTheme.Colors.goodDayGreen,
            JournalTheme.Colors.inkBlue,
            Color.yellow,
            Color.orange,
            Color.pink
        ]

        // Left side confetti (angled right and up)
        for i in 0..<25 {
            let particle = ConfettiParticle(
                id: i,
                x: -20,
                y: UIScreen.main.bounds.height * 0.6,
                color: colors.randomElement() ?? .green,
                velocityX: CGFloat.random(in: 150...350),
                velocityY: CGFloat.random(in: (-600)...(-300)),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: (-720)...720),
                size: CGFloat.random(in: 8...14),
                shape: ConfettiShape.allCases.randomElement() ?? .rectangle
            )
            confettiParticles.append(particle)
        }

        // Right side confetti (angled left and up)
        for i in 25..<50 {
            let particle = ConfettiParticle(
                id: i,
                x: UIScreen.main.bounds.width + 20,
                y: UIScreen.main.bounds.height * 0.6,
                color: colors.randomElement() ?? .green,
                velocityX: CGFloat.random(in: (-350)...(-150)),
                velocityY: CGFloat.random(in: (-600)...(-300)),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: (-720)...720),
                size: CGFloat.random(in: 8...14),
                shape: ConfettiShape.allCases.randomElement() ?? .rectangle
            )
            confettiParticles.append(particle)
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id: Int
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let velocityX: CGFloat
    let velocityY: CGFloat
    var rotation: Double
    let rotationSpeed: Double
    let size: CGFloat
    let shape: ConfettiShape
}

enum ConfettiShape: CaseIterable {
    case rectangle
    case circle
    case triangle
}

struct ConfettiPiece: View {
    let particle: ConfettiParticle
    @State private var position: CGPoint
    @State private var rotation: Double
    @State private var opacity: Double = 1

    init(particle: ConfettiParticle) {
        self.particle = particle
        _position = State(initialValue: CGPoint(x: particle.x, y: particle.y))
        _rotation = State(initialValue: particle.rotation)
    }

    var body: some View {
        Group {
            switch particle.shape {
            case .rectangle:
                Rectangle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size * 0.6)
            case .circle:
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
            case .triangle:
                Triangle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
            }
        }
        .rotationEffect(.degrees(rotation))
        .position(position)
        .opacity(opacity)
        .onAppear {
            // Animate the particle with physics
            withAnimation(.easeOut(duration: 2.5)) {
                position = CGPoint(
                    x: particle.x + particle.velocityX * 2,
                    y: particle.y + particle.velocityY * 2 + 800 // gravity pulls down
                )
                rotation = particle.rotation + particle.rotationSpeed * 2
                opacity = 0
            }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A habit row for time-of-day view - shows colored type pill on right and optional group name
struct TimeSlotHabitRow: View {
    let habit: Habit
    let groupName: String?
    let isCompleted: Bool
    let lineHeight: CGFloat
    let onComplete: () -> Void
    let onUncomplete: () -> Void
    let onTap: () -> Void
    let onLongPress: () -> Void

    // Swipe gesture state
    @State private var strikethroughProgress: CGFloat
    @State private var isDragging: Bool = false
    @State private var hasPassedThreshold: Bool = false
    @State private var textWidth: CGFloat = 0
    @State private var resetTask: Task<Void, Never>? = nil

    private let completionThreshold: CGFloat = 0.3

    init(habit: Habit, groupName: String?, isCompleted: Bool, lineHeight: CGFloat,
         onComplete: @escaping () -> Void,
         onUncomplete: @escaping () -> Void,
         onTap: @escaping () -> Void,
         onLongPress: @escaping () -> Void) {
        self.habit = habit
        self.groupName = groupName
        self.isCompleted = isCompleted
        self.lineHeight = lineHeight
        self.onComplete = onComplete
        self.onUncomplete = onUncomplete
        self.onTap = onTap
        self.onLongPress = onLongPress
        self._strikethroughProgress = State(initialValue: isCompleted ? 1.0 : 0.0)
        self._hasPassedThreshold = State(initialValue: isCompleted)
    }

    private var isVisuallyCompleted: Bool {
        strikethroughProgress >= completionThreshold
    }

    /// Color for the type pill based on habit tier and type
    private var pillColor: Color {
        if habit.isTask {
            return JournalTheme.Colors.teal
        }
        switch habit.tier {
        case .mustDo:
            return JournalTheme.Colors.amber
        case .niceToDo:
            return JournalTheme.Colors.navy
        }
    }

    /// Label for the type pill
    private var pillLabel: String {
        if habit.isTask {
            return "Task"
        }
        switch habit.tier {
        case .mustDo:
            return "Must"
        case .niceToDo:
            return "Nice"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Bullet dot
            Circle()
                .fill(isVisuallyCompleted
                    ? JournalTheme.Colors.completedGray
                    : JournalTheme.Colors.inkBlack)
                .frame(width: 6, height: 6)

            // Habit text with strikethrough overlay
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(habit.name)
                        .font(JournalTheme.Fonts.habitName())
                        .foregroundStyle(
                            isVisuallyCompleted
                                ? JournalTheme.Colors.completedGray
                                : JournalTheme.Colors.inkBlack
                        )

                    if let criteria = habit.criteriaDisplayString {
                        Text("(\(criteria))")
                            .font(JournalTheme.Fonts.habitCriteria())
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }
                }
                .background(
                    GeometryReader { textGeometry in
                        Color.clear
                            .onAppear { textWidth = textGeometry.size.width }
                            .onChange(of: textGeometry.size.width) { _, newWidth in
                                textWidth = newWidth
                            }
                    }
                )
                .overlay(alignment: .leading) {
                    StrikethroughLine(
                        width: textWidth > 0 ? textWidth : 200,
                        color: JournalTheme.Colors.inkBlue,
                        progress: $strikethroughProgress
                    )
                }

                // Group subtitle if habit is in a group
                if let groupName = groupName {
                    Text("from: \(groupName)")
                        .font(.custom("PatrickHand-Regular", size: 11))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                        .italic()
                }
            }

            Spacer()

            // Type pill on the right
            Text(pillLabel)
                .font(.custom("PatrickHand-Regular", size: 10))
                .foregroundStyle(pillColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(pillColor.opacity(0.12))
                )
        }
        .frame(minHeight: 44)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
        .gesture(completionGesture(hitboxWidth: 300))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    Feedback.longPress()
                    onLongPress()
                }
        )
        .onTapGesture {
            // Tap to open edit view
            Feedback.selection()
            onTap()
        }
        .onChange(of: isCompleted) { _, newValue in
            if !isDragging {
                withAnimation(JournalTheme.Animations.strikethrough) {
                    strikethroughProgress = newValue ? 1.0 : 0.0
                    hasPassedThreshold = newValue
                }
            }
        }
        .onChange(of: isDragging) { _, newValue in
            if !newValue {
                resetTask?.cancel()
                resetTask = Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if !Task.isCancelled {
                        await MainActor.run {
                            if !isCompleted && strikethroughProgress > 0 && strikethroughProgress < 1 {
                                withAnimation(JournalTheme.Animations.strikethrough) {
                                    strikethroughProgress = 0
                                    hasPassedThreshold = false
                                }
                            }
                        }
                    }
                }
            } else {
                resetTask?.cancel()
            }
        }
    }

    private func completionGesture(hitboxWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                let translation = value.translation.width

                guard horizontal > vertical, translation > 0 else { return }

                Feedback.startSwiping()
                isDragging = true

                if !isCompleted {
                    let forwardProgress = translation / hitboxWidth
                    strikethroughProgress = max(0, min(1, forwardProgress))

                    let currentlyPastThreshold = strikethroughProgress >= completionThreshold
                    if currentlyPastThreshold != hasPassedThreshold {
                        hasPassedThreshold = currentlyPastThreshold
                        Feedback.thresholdCrossed()
                    }
                }
            }
            .onEnded { value in
                isDragging = false
                let translation = value.translation.width

                guard translation > 0 else {
                    Feedback.stopSwiping()
                    return
                }

                if !isCompleted {
                    if strikethroughProgress >= completionThreshold {
                        withAnimation(JournalTheme.Animations.strikethrough) {
                            strikethroughProgress = 1.0
                        }
                        Feedback.swipeCompleted()
                        onComplete()
                        hasPassedThreshold = true
                    } else {
                        withAnimation(JournalTheme.Animations.strikethrough) {
                            strikethroughProgress = 0
                        }
                        Feedback.swipeCancelled()
                        hasPassedThreshold = false
                    }
                } else {
                    Feedback.stopSwiping()
                }
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Habit.self, HabitGroup.self, DailyLog.self], inMemory: true)
}
