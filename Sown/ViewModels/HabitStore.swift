import Foundation
import SwiftData
import SwiftUI
import UserNotifications
import WidgetKit

@Observable
final class HabitStore {
    private var modelContext: ModelContext

    var habits: [Habit] = []
    var allHabits: [Habit] = []
    var groups: [HabitGroup] = []
    var dayRecords: [DayRecord] = []
    var endOfDayNotes: [EndOfDayNote] = []
    var selectedDate: Date = Date()

    /// Counter that increments whenever a habit completion changes - used for efficient change detection
    var completionChangeCounter: Int = 0

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchData()
    }

    // MARK: - Data Fetching

    func fetchData() {
        fetchHabits()
        fetchAllHabits()
        fetchGroups()
        fetchDayRecords()
        fetchEndOfDayNotes()
        WidgetDataService.updateWidgetData(from: self)
    }

    /// Prefetch today's DailyLogs via a direct query so that `habit.isCompleted(for:)`
    /// doesn't trigger lazy relationship faulting during view rendering.
    /// Also faults the dailyLogs relationship for the Month tab.
    func prefetchDailyLogs() {
        // 1. Fetch today's logs directly — this is a single indexed query, much faster
        //    than faulting every habit's relationship.
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) else { return }

        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate<DailyLog> { log in
                log.date >= startOfToday && log.date < endOfToday
            }
        )
        if let todayLogs = try? modelContext.fetch(descriptor) {
            // Accessing these logs faults them into the context's row cache.
            // When habit.isCompleted(for:) later walks habit.dailyLogs,
            // the matching DailyLog is already in memory — no disk I/O.
            for log in todayLogs {
                _ = log.completed
                _ = log.date
            }
        }
    }

    private func fetchHabits() {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        do {
            habits = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch habits: \(error)")
            habits = []
        }
    }

    private func fetchAllHabits() {
        let descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        do {
            allHabits = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch all habits: \(error)")
            allHabits = []
        }
    }

    // MARK: - Live/Archived Habits

    var liveHabits: [Habit] {
        allHabits.filter { $0.isActive }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var archivedHabits: [Habit] {
        allHabits.filter { !$0.isActive }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func archiveHabit(_ habit: Habit) {
        habit.isActive = false
        saveContext()
        fetchHabits()
        fetchAllHabits()
    }

    func unarchiveHabit(_ habit: Habit) {
        habit.isActive = true
        saveContext()
        fetchHabits()
        fetchAllHabits()
    }

    func reorderHabits(_ habits: [Habit]) {
        for (index, habit) in habits.enumerated() {
            habit.sortOrder = index
        }
        saveContext()
        fetchAllHabits()
    }

    private func fetchGroups() {
        let descriptor = FetchDescriptor<HabitGroup>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        do {
            groups = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch groups: \(error)")
            groups = []
        }
    }

    private func fetchDayRecords() {
        let descriptor = FetchDescriptor<DayRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        do {
            dayRecords = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch day records: \(error)")
            dayRecords = []
        }
    }

    private func fetchEndOfDayNotes() {
        let descriptor = FetchDescriptor<EndOfDayNote>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        do {
            endOfDayNotes = try modelContext.fetch(descriptor)
            // Auto-lock notes past grace period
            lockExpiredNotes()
        } catch {
            print("Failed to fetch end-of-day notes: \(error)")
            endOfDayNotes = []
        }
    }

    // MARK: - End of Day Notes

    /// Returns the end-of-day note for a given date, if one exists
    func endOfDayNote(for date: Date) -> EndOfDayNote? {
        let calendar = Calendar.current
        return endOfDayNotes.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// Creates or updates an end-of-day note
    @discardableResult
    func saveEndOfDayNote(for date: Date, note: String, fulfillmentScore: Int) -> EndOfDayNote {
        if let existing = endOfDayNote(for: date) {
            guard existing.isEditable else { return existing }
            existing.note = note
            existing.fulfillmentScore = fulfillmentScore
            saveContext()
            fetchEndOfDayNotes()
            return existing
        }

        let newNote = EndOfDayNote(
            date: date,
            note: note,
            fulfillmentScore: fulfillmentScore
        )
        modelContext.insert(newNote)
        saveContext()
        fetchEndOfDayNotes()
        return newNote
    }

    /// Lock notes that are past the grace period (end of next day)
    private func lockExpiredNotes() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for note in endOfDayNotes where !note.isLocked {
            let noteDay = calendar.startOfDay(for: note.date)
            guard let gracePeriodEnd = calendar.date(byAdding: .day, value: 2, to: noteDay) else { continue }
            if today >= gracePeriodEnd {
                note.isLocked = true
            }
        }
        saveContext()
    }

    /// Returns all end-of-day notes for a given number of past days, newest first
    func recentEndOfDayNotes(days: Int = 30) -> [EndOfDayNote] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }
        return endOfDayNotes.filter { $0.date >= startDate }
    }

    // MARK: - Filtered Habits

    var mustDoHabits: [Habit] {
        habits.filter { $0.tier == .mustDo && !$0.isTask }
    }

    var niceToDoHabits: [Habit] {
        habits.filter { $0.tier == .niceToDo && !$0.isTask }
    }

    /// All negative habits (things to avoid)
    var negativeHabits: [Habit] {
        habits.filter { $0.type == .negative && !$0.isTask }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// One-off tasks (frequency == .once) that are active
    var todayTasks: [Habit] {
        habits.filter { $0.isTask }
    }

    /// All recurring habits (excludes one-off tasks) — for stats and month views
    var recurringHabits: [Habit] {
        habits.filter { !$0.isTask }
    }

    /// Positive must-do habits not in any group (excludes negative)
    var standalonePositiveMustDoHabits: [Habit] {
        let groupedHabitIds = Set(mustDoGroups.flatMap { $0.habitIds })
        return mustDoHabits.filter {
            !groupedHabitIds.contains($0.id) && $0.type == .positive
        }
    }

    /// Positive nice-to-do habits (excludes negative and tasks)
    var positiveNiceToDoHabits: [Habit] {
        niceToDoHabits.filter { $0.type == .positive && !$0.isTask }
    }

    /// Uncompleted one-off tasks: created today OR rolled over from previous days, excluding completed
    var todayVisibleTasks: [Habit] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return habits.filter { habit in
            guard habit.isTask else { return false }
            // Exclude completed tasks (they appear in todayCompletedTasks)
            guard !habit.isCompleted(for: today) else { return false }
            let createdDay = calendar.startOfDay(for: habit.createdAt)
            // Show if created today, or if created before today and still uncompleted (rollover)
            return createdDay == today || !habit.isCompleted(for: createdDay)
        }
    }

    /// Completed tasks for today (to show in done section)
    var todayCompletedTasks: [Habit] {
        let today = Date()
        return habits.filter { $0.isTask && $0.isCompleted(for: today) }
    }

    var mustDoGroups: [HabitGroup] {
        groups.filter { $0.tier == .mustDo }
    }

    var niceToDoGroups: [HabitGroup] {
        groups.filter { $0.tier == .niceToDo }
    }

    /// Returns habits that are not in any must-do group (standalone must-dos)
    var standaloneMustDoHabits: [Habit] {
        let groupedHabitIds = Set(mustDoGroups.flatMap { $0.habitIds })
        return mustDoHabits.filter { !groupedHabitIds.contains($0.id) }
    }

    /// Returns habits for a specific group
    func habits(for group: HabitGroup) -> [Habit] {
        habits.filter { group.habitIds.contains($0.id) }
    }

    // MARK: - Habit CRUD Operations

    @discardableResult
    func addHabit(
        name: String,
        description: String = "",
        tier: HabitTier = .mustDo,
        type: HabitType = .positive,
        frequencyType: FrequencyType = .daily,
        frequencyTarget: Int = 1,
        successCriteria: String? = nil,
        groupId: UUID? = nil,
        isHobby: Bool = false,
        iconImageData: Data? = nil,
        notificationsEnabled: Bool = false,
        dailyNotificationMinutes: [Int] = [],
        weeklyNotificationDays: [Int] = [],
        options: [String] = [],
        enableNotesPhotos: Bool = false,
        habitPrompt: String = "",
        scheduleTimes: [String] = [],
        triggersAppBlockSlip: Bool = false,
        healthKitMetricType: String? = nil,
        healthKitTarget: Double? = nil,
        screenTimeAppTokenData: Data? = nil,
        screenTimeTarget: Int? = nil,
        taskDeadlineMinutes: Int? = nil
    ) -> Habit {
        let maxSortOrder = habits.map { $0.sortOrder }.max() ?? 0

        // Tasks are always nice-to-do and positive
        let effectiveTier: HabitTier = frequencyType == .once ? .niceToDo : tier
        let effectiveType: HabitType = frequencyType == .once ? .positive : type

        let habit = Habit(
            name: name,
            habitDescription: description,
            tier: effectiveTier,
            type: effectiveType,
            frequencyType: frequencyType,
            frequencyTarget: frequencyTarget,
            successCriteria: successCriteria,
            groupId: groupId,
            sortOrder: maxSortOrder + 1,
            isHobby: isHobby
        )
        habit.iconImageData = iconImageData
        habit.notificationsEnabled = notificationsEnabled
        habit.dailyNotificationMinutes = dailyNotificationMinutes
        habit.weeklyNotificationDays = weeklyNotificationDays
        habit.options = options
        habit.enableNotesPhotos = enableNotesPhotos
        habit.habitPrompt = habitPrompt
        habit.scheduleTimes = scheduleTimes
        habit.triggersAppBlockSlip = triggersAppBlockSlip
        habit.healthKitMetricType = healthKitMetricType
        habit.healthKitTarget = healthKitTarget
        habit.screenTimeAppTokenData = screenTimeAppTokenData
        habit.screenTimeTarget = screenTimeTarget
        habit.taskDeadlineMinutes = taskDeadlineMinutes

        modelContext.insert(habit)
        saveContext()
        fetchHabits()
        fetchAllHabits()

        // Reschedule notifications (auto-scheduled based on time slots)
        refreshNotifications()

        // Schedule task deadline notifications if applicable
        if frequencyType == .once && taskDeadlineMinutes != nil {
            Task {
                await UnifiedNotificationService.shared.scheduleTaskDeadlineNotifications(for: habit)
            }
        }

        // Start Screen Time monitoring if habit is linked
        if screenTimeAppTokenData != nil && screenTimeTarget != nil {
            startScreenTimeMonitoring()
        }

        WidgetDataService.updateWidgetData(from: self)
        return habit
    }

    func updateHabit(_ habit: Habit) {
        saveContext()
        fetchHabits()
        fetchAllHabits()

        // Reschedule notifications (auto-scheduled based on time slots)
        refreshNotifications()
        WidgetDataService.updateWidgetData(from: self)
    }

    func deleteHabit(_ habit: Habit) {
        // Cancel any scheduled notifications for this habit
        Task {
            await NotificationService.shared.cancelNotifications(for: habit)
            await UnifiedNotificationService.shared.cancelNotifications(for: habit)
            if habit.isTask {
                await UnifiedNotificationService.shared.cancelTaskDeadlineNotifications(for: habit)
            }
        }

        // Remove from any groups
        for group in groups where group.habitIds.contains(habit.id) {
            group.habitIds.removeAll { $0 == habit.id }
        }

        // Remove from local arrays
        habits.removeAll { $0.id == habit.id }
        allHabits.removeAll { $0.id == habit.id }

        // Then delete from database
        modelContext.delete(habit)
        saveContext()
        WidgetDataService.updateWidgetData(from: self)
    }

    /// Delete completed today-only tasks from previous days (or after cleanup time today)
    func cleanupExpiredTodayTasks() {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        // 0 = midnight (tasks only cleaned up when the next day starts)
        let cleanupMinutes = 0

        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        let expiredTasks = habits.filter { habit in
            guard habit.isTask else { return false }
            // Check if completed on ANY day (not just creation day)
            guard (habit.dailyLogs ?? []).contains(where: { $0.completed }) else { return false }

            let createdDay = calendar.startOfDay(for: habit.createdAt)

            if createdDay < startOfToday {
                // Task from a previous day — always clean up
                return true
            }
            if cleanupMinutes > 0 && currentMinutes >= cleanupMinutes && createdDay == startOfToday {
                // Task from today, past cleanup time — clean up for testing
                return true
            }
            return false
        }

        for task in expiredTasks {
            print("[TaskCleanup] 🗑️ Deleting completed task: \(task.name)")
            deleteHabit(task)
        }

        if !expiredTasks.isEmpty {
            print("[TaskCleanup] Deleted \(expiredTasks.count) completed task(s)")
        }
    }

    func deactivateHabit(_ habit: Habit) {
        habit.isActive = false
        saveContext()
        fetchHabits()
    }

    // MARK: - Group CRUD Operations

    // MARK: - Batch Creation (used by onboarding)

    /// Insert multiple habits in one batch — saves and fetches only once at the end.
    @discardableResult
    func addHabitsBatch(
        _ drafts: [(
            name: String, tier: HabitTier, type: HabitType,
            frequencyType: FrequencyType, frequencyTarget: Int,
            successCriteria: String?, isHobby: Bool,
            enableNotesPhotos: Bool, habitPrompt: String,
            scheduleTimes: [String], triggersAppBlockSlip: Bool
        )]
    ) -> [Habit] {
        var maxSortOrder = habits.map { $0.sortOrder }.max() ?? 0
        var created: [Habit] = []

        for draft in drafts {
            let effectiveTier: HabitTier = draft.frequencyType == .once ? .niceToDo : draft.tier
            let effectiveType: HabitType = draft.frequencyType == .once ? .positive : draft.type

            let habit = Habit(
                name: draft.name,
                tier: effectiveTier,
                type: effectiveType,
                frequencyType: draft.frequencyType,
                frequencyTarget: draft.frequencyTarget,
                successCriteria: draft.successCriteria,
                sortOrder: maxSortOrder + 1,
                isHobby: draft.isHobby
            )
            habit.enableNotesPhotos = draft.enableNotesPhotos
            habit.habitPrompt = draft.habitPrompt
            habit.scheduleTimes = draft.scheduleTimes
            habit.triggersAppBlockSlip = draft.triggersAppBlockSlip

            modelContext.insert(habit)
            created.append(habit)
            maxSortOrder += 1
        }

        saveContext()
        fetchHabits()
        fetchAllHabits()
        refreshNotifications()
        return created
    }

    /// Insert multiple groups in one batch — saves and fetches only once at the end.
    func addGroupsBatch(
        _ groupDrafts: [(name: String, tier: HabitTier, requireCount: Int, habitIds: [UUID])]
    ) {
        var maxSortOrder = groups.map { $0.sortOrder }.max() ?? 0

        for draft in groupDrafts {
            let group = HabitGroup(
                name: draft.name,
                tier: draft.tier,
                requireCount: draft.requireCount,
                habitIds: draft.habitIds,
                sortOrder: maxSortOrder + 1
            )
            modelContext.insert(group)
            maxSortOrder += 1

            for habitId in draft.habitIds {
                if let habit = habits.first(where: { $0.id == habitId }) {
                    habit.groupId = group.id
                }
            }
        }

        saveContext()
        fetchGroups()
    }

    func addGroup(
        name: String,
        tier: HabitTier = .mustDo,
        requireCount: Int = 1,
        habitIds: [UUID] = []
    ) {
        let maxSortOrder = groups.map { $0.sortOrder }.max() ?? 0
        let group = HabitGroup(
            name: name,
            tier: tier,
            requireCount: requireCount,
            habitIds: habitIds,
            sortOrder: maxSortOrder + 1
        )
        modelContext.insert(group)

        // Update habits to reference this group
        for habitId in habitIds {
            if let habit = habits.first(where: { $0.id == habitId }) {
                habit.groupId = group.id
            }
        }

        saveContext()
        fetchGroups()
    }

    func updateGroup(_ group: HabitGroup) {
        saveContext()
        fetchGroups()
    }

    func deleteGroup(_ group: HabitGroup) {
        // Remove group reference from habits
        for habitId in group.habitIds {
            if let habit = habits.first(where: { $0.id == habitId }) {
                habit.groupId = nil
            }
        }

        modelContext.delete(group)
        saveContext()
        fetchGroups()
    }

    /// Creates a new group by combining two habits (iOS folder-style creation)
    func createGroupFromHabits(_ habit1: Habit, _ habit2: Habit) -> HabitGroup {
        // Use the tier of the first habit
        let tier = habit1.tier

        // Create a default name
        let groupName = "New Group"

        let maxSortOrder = groups.map { $0.sortOrder }.max() ?? 0
        let group = HabitGroup(
            name: groupName,
            tier: tier,
            requireCount: 1,
            habitIds: [habit1.id, habit2.id],
            sortOrder: maxSortOrder + 1
        )
        modelContext.insert(group)

        // Update habits to reference this group
        habit1.groupId = group.id
        habit2.groupId = group.id

        saveContext()
        fetchGroups()

        return group
    }

    func addHabitToGroup(_ habit: Habit, group: HabitGroup) {
        if !group.habitIds.contains(habit.id) {
            group.habitIds.append(habit.id)
            habit.groupId = group.id
            saveContext()
            fetchGroups()
        }
    }

    func removeHabitFromGroup(_ habit: Habit, group: HabitGroup) {
        group.habitIds.removeAll { $0 == habit.id }
        habit.groupId = nil
        saveContext()
        fetchGroups()
    }

    // MARK: - Completion Logic

    func toggleCompletion(for habit: Habit, on date: Date = Date()) {
        let isCurrentlyCompleted = habit.isCompleted(for: date)
        let newCompletedState = !isCurrentlyCompleted

        _ = DailyLog.createOrUpdate(
            for: habit,
            on: date,
            completed: newCompletedState,
            context: modelContext
        )

        // Update streaks
        updateStreak(for: habit)

        completionChangeCounter += 1
        saveContext()
        refreshNotifications()
        WidgetDataService.updateWidgetData(from: self)

        // Update task deadline notifications based on completion state
        if habit.isTask && habit.taskDeadlineMinutes != nil {
            Task {
                if newCompletedState {
                    await UnifiedNotificationService.shared.cancelTaskDeadlineNotifications(for: habit)
                } else {
                    await UnifiedNotificationService.shared.scheduleTaskDeadlineNotifications(for: habit)
                }
            }
        }
    }

    func setCompletion(for habit: Habit, completed: Bool, value: Double? = nil, on date: Date = Date()) {
        _ = DailyLog.createOrUpdate(
            for: habit,
            on: date,
            completed: completed,
            value: value,
            context: modelContext
        )

        // Update streaks
        updateStreak(for: habit)

        completionChangeCounter += 1
        saveContext()
        refreshNotifications()
        WidgetDataService.updateWidgetData(from: self)

        // Update task deadline notifications based on completion state
        if habit.isTask && habit.taskDeadlineMinutes != nil {
            Task {
                if completed {
                    await UnifiedNotificationService.shared.cancelTaskDeadlineNotifications(for: habit)
                } else {
                    await UnifiedNotificationService.shared.scheduleTaskDeadlineNotifications(for: habit)
                }
            }
        }
    }

    /// Reschedules all habit notifications based on time slot assignments.
    /// Debounced to 1 second so rapid tapping doesn't trigger many reschedules.
    private var notificationDebounceTask: Task<Void, Never>?

    func refreshNotifications() {
        notificationDebounceTask?.cancel()
        notificationDebounceTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await UnifiedNotificationService.shared.scheduleAllHabitNotifications(for: self.habits)
        }
    }

    /// Records which sub-habit option was selected when completing a group habit
    func recordSelectedOption(for habit: Habit, option: String, on date: Date) {
        if let log = habit.log(for: date) {
            log.selectedOption = option
            saveContext()
        }
    }

    /// Saves hobby completion with optional note and photos (up to 3)
    func saveHobbyCompletion(for habit: Habit, on date: Date, note: String?, images: [UIImage]) {
        let savedPaths = PhotoStorageService.shared.savePhotos(images, for: habit.id, on: date)

        // Legacy single photo path (first image for backward compat)
        let legacyPath = savedPaths.first

        // Update existing DailyLog with note and photoPaths
        let log = DailyLog.createOrUpdate(
            for: habit,
            on: date,
            completed: true,
            note: note,
            photoPath: legacyPath,
            photoPaths: savedPaths,
            context: modelContext
        )

        // Ensure the log properties are set directly (SwiftData sometimes needs this)
        if let note = note {
            log.note = note
        }
        if let legacyPath = legacyPath {
            log.photoPath = legacyPath
        }
        log.photoPaths = savedPaths

        saveContext()
    }

    /// Updates an existing hobby log's note and photos
    func updateHobbyLog(for habit: Habit, on date: Date, note: String?, images: [UIImage]) {
        guard let log = habit.log(for: date), log.completed else { return }

        // Delete old photos
        for path in log.allPhotoPaths {
            PhotoStorageService.shared.deletePhoto(at: path)
        }

        // Save new photos
        let savedPaths = PhotoStorageService.shared.savePhotos(images, for: habit.id, on: date)
        let legacyPath = savedPaths.first

        log.note = note
        log.photoPath = legacyPath
        log.photoPaths = savedPaths

        saveContext()
    }

    // MARK: - Good Day Logic

    /// Check if a date is a good day.
    /// For past dates with a locked DayRecord, uses the locked value.
    /// For today and unlocked dates, calculates live from current habit state.
    func isGoodDay(for date: Date) -> Bool {
        // Check for a locked DayRecord first (applies to past days locked at midnight)
        if let record = dayRecord(for: date), record.lockedAt != nil {
            return record.isGoodDay
        }

        // Live calculation for today and unlocked past dates
        return isGoodDayLive(for: date)
    }

    /// Live calculation of good day status from current habit state.
    /// Used for today and for evaluating whether to lock at midnight.
    private func isGoodDayLive(for date: Date) -> Bool {
        // Get standalone POSITIVE must-do habits (not in any group, excludes negative)
        // Only count habits that existed on this date
        let standaloneMustDos = mustDoHabits.filter { habit in
            habit.groupId == nil && habit.type == .positive &&
            Calendar.current.startOfDay(for: habit.createdAt) <= Calendar.current.startOfDay(for: date)
        }

        // Only count groups that had at least one member on this date
        let applicableGroups = mustDoGroups.filter { group in
            let memberHabits = habits.filter { group.habitIds.contains($0.id) }
            return memberHabits.contains { Calendar.current.startOfDay(for: $0.createdAt) <= Calendar.current.startOfDay(for: date) }
        }

        // If there are no positive must-do habits AND no must-do groups, it's not a "good day"
        if standaloneMustDos.isEmpty && applicableGroups.isEmpty {
            return false
        }

        // All standalone positive must-do habits must be completed
        let allMustDosCompleted = standaloneMustDos.allSatisfy { $0.isCompleted(for: date) }

        // All must-do groups must be satisfied
        let allGroupsSatisfied = applicableGroups.allSatisfy { group in
            group.isSatisfied(habits: habits, for: date)
        }

        // All negative habits must NOT be completed (no slips)
        let noNegativeSlips = negativeHabits.allSatisfy { !$0.isCompleted(for: date) }

        return allMustDosCompleted && allGroupsSatisfied && noNegativeSlips
    }

    /// Returns the DayRecord for a specific date, if one exists.
    func dayRecord(for date: Date) -> DayRecord? {
        let calendar = Calendar.current
        return dayRecords.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// Lock yesterday's good day status. Called at midnight (or when the app opens on a new day).
    /// If yesterday was a good day, it gets permanently locked.
    func lockPreviousDayIfNeeded() {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!

        // Persist final HealthKit values for yesterday before locking
        Task {
            await persistFinalHealthKitValues(for: yesterday)
        }

        // Already locked? Skip
        if let existing = dayRecord(for: yesterday), existing.lockedAt != nil {
            return
        }

        let wasGood = isGoodDayLive(for: yesterday)

        if let existing = dayRecord(for: yesterday) {
            existing.isGoodDay = wasGood
            existing.lockedAt = Date()
        } else {
            let record = DayRecord(date: yesterday, isGoodDay: wasGood, lockedAt: Date())
            modelContext.insert(record)
        }

        saveContext()
        fetchDayRecords()
    }

    /// Persist final HealthKit values for a past day (called at day change)
    /// This ensures that even if the target wasn't reached, the actual value is saved for stats
    @MainActor
    func persistFinalHealthKitValues(for date: Date) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        for habit in healthKitLinkedHabits {
            guard let metric = habit.healthKitMetric else { continue }

            // Skip if we already have a value stored for this date
            if habit.completionValue(for: date) != nil { continue }

            // Fetch the historical HealthKit value for this date
            if let value = await HealthKitManager.shared.fetchValueForDateRange(
                for: metric,
                start: startOfDay,
                end: endOfDay
            ) {
                // Only store if there's actual data (not zero)
                if value > 0 {
                    // Check if habit was completed (auto or manual)
                    let wasCompleted = habit.isCompleted(for: date)

                    // Create or update log with the value, preserving completion state
                    _ = DailyLog.createOrUpdate(
                        for: habit,
                        on: date,
                        completed: wasCompleted,
                        value: value,
                        context: modelContext
                    )
                }
            }
        }

        saveContext()
    }

    /// Returns good days in a date range
    func goodDays(from startDate: Date, to endDate: Date) -> [Date] {
        var goodDays: [Date] = []
        let calendar = Calendar.current
        var currentDate = startDate

        while currentDate <= endDate {
            if isGoodDay(for: currentDate) {
                goodDays.append(currentDate)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return goodDays
    }

    // MARK: - Must-Do Progress (for streak tracker bar)

    /// Total number of must-do items for today (standalone habits + groups)
    func mustDoTotalCount(for date: Date) -> Int {
        let standaloneMustDos = mustDoHabits.filter { $0.groupId == nil && $0.type == .positive }
        return standaloneMustDos.count + mustDoGroups.count
    }

    /// Number of completed must-do items for today
    func mustDoCompletedCount(for date: Date) -> Int {
        let standaloneMustDos = mustDoHabits.filter { $0.groupId == nil && $0.type == .positive }
        let completedStandalone = standaloneMustDos.filter { $0.isCompleted(for: date) }.count
        let completedGroups = mustDoGroups.filter { $0.isSatisfied(habits: habits, for: date) }.count
        return completedStandalone + completedGroups
    }

    /// Current good-day streak (consecutive days where all must-dos were completed)
    func currentGoodDayStreak() -> Int {
        var streak = 0
        let calendar = Calendar.current
        var date = calendar.startOfDay(for: Date())

        if isGoodDay(for: date) {
            streak = 1
            date = calendar.date(byAdding: .day, value: -1, to: date)!
        } else {
            date = calendar.date(byAdding: .day, value: -1, to: date)!
        }

        var daysChecked = 0
        while isGoodDay(for: date) && daysChecked < 365 {
            streak += 1
            date = calendar.date(byAdding: .day, value: -1, to: date)!
            daysChecked += 1
        }

        return streak
    }

    /// Completed nice-to-do habits for a given date (for the Done section)
    func completedNiceToDoHabits(for date: Date) -> [Habit] {
        positiveNiceToDoHabits.filter { $0.isCompleted(for: date) }
    }

    /// Uncompleted nice-to-do habits for a given date
    func uncompletedNiceToDoHabits(for date: Date) -> [Habit] {
        positiveNiceToDoHabits.filter { !$0.isCompleted(for: date) }
    }

    /// Completed standalone must-do habits for a given date (for the Done section)
    func completedStandaloneMustDoHabits(for date: Date) -> [Habit] {
        standalonePositiveMustDoHabits.filter { $0.isCompleted(for: date) }
    }

    /// Uncompleted standalone must-do habits for a given date
    func uncompletedStandaloneMustDoHabits(for date: Date) -> [Habit] {
        standalonePositiveMustDoHabits.filter { !$0.isCompleted(for: date) }
    }

    // MARK: - Time of Day Sorting

    /// Returns habits without any schedule times (anytime habits) that are uncompleted
    func anytimeHabits(for date: Date) -> [Habit] {
        habits.filter { habit in
            habit.type == .positive &&
            !habit.isTask &&
            habit.scheduleTimes.isEmpty &&
            !habit.isCompleted(for: date)
        }
    }

    /// Returns habits for a specific time slot that are uncompleted
    func habitsForTimeSlot(_ slot: TimeSlot, on date: Date) -> [Habit] {
        habits.filter { habit in
            habit.type == .positive &&
            !habit.isTask &&
            habit.scheduleTimes.contains(slot.rawValue) &&
            !habit.isCompleted(for: date)
        }
    }

    /// Returns the group name for a habit if it belongs to a group, nil otherwise
    func groupName(for habit: Habit) -> String? {
        guard let groupId = habit.groupId else { return nil }
        return groups.first { $0.id == groupId }?.name
    }

    // MARK: - Streak Calculation

    func updateStreak(for habit: Habit) {
        if habit.type == .negative {
            // For negative habits, streak = days since last done
            let daysSince = calculateDaysSinceLastDone(for: habit)
            habit.currentStreak = daysSince
            if daysSince > habit.bestStreak {
                habit.bestStreak = daysSince
            }
        } else {
            // Existing logic for positive habits
            let streak = calculateCurrentStreak(for: habit)
            habit.currentStreak = streak
            if streak > habit.bestStreak {
                habit.bestStreak = streak
            }
        }
    }

    /// Calculates days since habit was last completed (for negative habits, "completed" = slipped).
    /// Returns -1 if the habit was created today and has never slipped (so the UI can show "new" instead of "0 days").
    func calculateDaysSinceLastDone(for habit: Habit) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let completedLogs = (habit.dailyLogs ?? [])
            .filter { $0.completed }
            .sorted { $0.date > $1.date }

        guard let lastCompletedLog = completedLogs.first else {
            // Never slipped - count from creation date
            let creationDay = calendar.startOfDay(for: habit.createdAt)
            let daysSinceCreation = calendar.dateComponents([.day], from: creationDay, to: today).day ?? 0
            // Created today with no slips — return -1 so UI doesn't show "slipped"
            if daysSinceCreation == 0 { return -1 }
            return daysSinceCreation
        }

        let lastCompletedDate = calendar.startOfDay(for: lastCompletedLog.date)
        let daysSince = calendar.dateComponents([.day], from: lastCompletedDate, to: today).day ?? 0
        return max(0, daysSince)
    }

    func calculateCurrentStreak(for habit: Habit) -> Int {
        // Tasks don't have streaks
        if habit.isTask { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch habit.frequencyType {
        case .once:
            return 0
        case .daily:
            return calculateDailyStreak(for: habit, from: today)
        case .weekly:
            return calculateWeeklyStreak(for: habit, target: habit.frequencyTarget, from: today)
        case .monthly:
            return calculateMonthlyStreak(for: habit, target: habit.frequencyTarget, from: today)
        }
    }

    private func calculateDailyStreak(for habit: Habit, from date: Date) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = date

        // Check if today is completed
        if habit.isCompleted(for: checkDate) {
            streak = 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        } else {
            // If today is not completed, check yesterday to see if streak is still alive
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        // Count backwards
        while habit.isCompleted(for: checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        return streak
    }

    private func calculateWeeklyStreak(for habit: Habit, target: Int, from date: Date) -> Int {
        let calendar = Calendar.current
        var streak = 0

        // Get the start of current week
        var weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!

        // Check current week
        let currentWeekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        let currentWeekCompletions = habit.completionCount(from: weekStart, to: min(date, currentWeekEnd))

        if currentWeekCompletions >= target {
            streak = 1
        }

        // Count previous weeks
        weekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart)!

        while true {
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            let completions = habit.completionCount(from: weekStart, to: weekEnd)

            if completions >= target {
                streak += 1
                weekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart)!
            } else {
                break
            }
        }

        return streak
    }

    private func calculateMonthlyStreak(for habit: Habit, target: Int, from date: Date) -> Int {
        let calendar = Calendar.current
        var streak = 0

        // Get the start of current month
        var monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!

        // Check current month
        let currentMonthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!
        let currentMonthCompletions = habit.completionCount(from: monthStart, to: min(date, currentMonthEnd))

        if currentMonthCompletions >= target {
            streak = 1
        }

        // Count previous months
        monthStart = calendar.date(byAdding: .month, value: -1, to: monthStart)!

        while true {
            let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!
            let completions = habit.completionCount(from: monthStart, to: monthEnd)

            if completions >= target {
                streak += 1
                monthStart = calendar.date(byAdding: .month, value: -1, to: monthStart)!
            } else {
                break
            }
        }

        return streak
    }

    // MARK: - Statistics

    func completionRate(for habit: Habit, days: Int = 30) -> Double {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        // Use -(days - 1) because today counts as day 1
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: endDate) else { return 0 }

        let completedDays = habit.completionCount(from: startDate, to: endDate)
        return Double(completedDays) / Double(days)
    }

    func goodDayRate(days: Int = 30) -> Double {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        // Use -(days - 1) because today counts as day 1
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: endDate) else { return 0 }

        let goodDaysList = goodDays(from: startDate, to: endDate)
        return Double(goodDaysList.count) / Double(days)
    }

    // MARK: - Sample Data

    func createSampleData() {
        // Only create if no habits exist
        guard habits.isEmpty else { return }

        // Must-do habits
        addHabit(name: "Brush teeth", tier: .mustDo, type: .positive, frequencyType: .daily)
        addHabit(name: "Floss", tier: .mustDo, type: .positive, frequencyType: .daily)
        addHabit(name: "Drink water", tier: .mustDo, type: .positive, frequencyType: .daily, successCriteria: "3L")
        addHabit(name: "Wake up by 9am", tier: .mustDo, type: .positive, frequencyType: .daily)
        addHabit(name: "Sleep by midnight", tier: .mustDo, type: .positive, frequencyType: .daily)
        addHabit(name: "Go outside", tier: .mustDo, type: .positive, frequencyType: .daily)

        // Nice-to-do habits
        addHabit(name: "Guitar 🎸", tier: .niceToDo, type: .positive, frequencyType: .daily, successCriteria: "15 mins")
        addHabit(name: "Draw 🎨", tier: .niceToDo, type: .positive, frequencyType: .daily)
        addHabit(name: "Exercise", tier: .niceToDo, type: .positive, frequencyType: .weekly, frequencyTarget: 4)
        addHabit(name: "Morning walk", tier: .niceToDo, type: .positive, frequencyType: .daily)

        fetchHabits()

        // Create "Do something creative" group
        let guitarHabit = habits.first { $0.name.contains("Guitar") }
        let drawHabit = habits.first { $0.name.contains("Draw") }

        if let guitar = guitarHabit, let draw = drawHabit {
            addGroup(
                name: "Do something creative",
                tier: .mustDo,
                requireCount: 1,
                habitIds: [guitar.id, draw.id]
            )
        }
    }

    // MARK: - Private Helpers

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }

    // MARK: - Screen Time Integration

    /// All habits linked to Screen Time that are active
    var screenTimeLinkedHabits: [Habit] {
        habits.filter { $0.isScreenTimeLinked && $0.isActive }
    }

    /// Check all Screen Time habits and auto-complete if target reached
    /// - Parameter triggerNotification: Whether to send a notification (for background updates)
    func checkScreenTimeCompletions(triggerNotification: Bool = false) {
        let today = Date()
        let completedIds = ScreenTimeUsageManager.shared.getCompletedHabitIds()

        for habit in screenTimeLinkedHabits {
            guard habit.screenTimeAutoComplete,
                  completedIds.contains(habit.id.uuidString),
                  !habit.isCompleted(for: today) else { continue }

            autoCompleteScreenTimeHabit(habit, triggerNotification: triggerNotification)
        }

        // Also check for slipped negative habits
        checkScreenTimeSlips()
    }

    /// Check all negative Screen Time habits and auto-slip if limit exceeded
    func checkScreenTimeSlips() {
        let today = Date()
        let slippedIds = ScreenTimeUsageManager.shared.getSlippedHabitIds(for: today)

        for habit in negativeHabits where habit.isScreenTimeLinked {
            guard slippedIds.contains(habit.id.uuidString),
                  !habit.isCompleted(for: today) else { continue }

            // Mark as slipped (completed = true for negative habits means slipped)
            setCompletion(for: habit, completed: true, on: today)
        }
    }

    /// Auto-complete a habit via Screen Time
    private func autoCompleteScreenTimeHabit(_ habit: Habit, triggerNotification: Bool) {
        let today = Date()

        // Create or update the log with auto-completion flag
        let log = DailyLog.createOrUpdate(
            for: habit,
            on: today,
            completed: true,
            context: modelContext
        )
        log.autoCompletedByScreenTime = true

        // Update streak
        updateStreak(for: habit)

        completionChangeCounter += 1
        saveContext()

        // Send notification if app is backgrounded
        if triggerNotification {
            let isAppInBackground = UIApplication.shared.applicationState != .active
            if isAppInBackground, let targetMinutes = habit.screenTimeTarget {
                ScreenTimeUsageManager.shared.sendAchievementNotification(
                    habitName: habit.name,
                    minutes: targetMinutes
                )
            }
        }

        // Refresh smart reminders since completion state changed
        refreshNotifications()

        // refreshNotifications() above already handles rescheduling
    }

    /// Start monitoring Screen Time for all linked habits (positive and negative)
    func startScreenTimeMonitoring() {
        guard ScreenTimeManager.shared.isAuthorized else { return }

        // Include both positive Screen Time habits and negative Screen Time habits
        let positiveLinked = screenTimeLinkedHabits
        let negativeLinked = negativeHabits.filter { $0.isScreenTimeLinked }
        let allLinked = Array(Set(positiveLinked + negativeLinked))

        guard !allLinked.isEmpty else { return }
        ScreenTimeUsageManager.shared.startMonitoringHabits(allLinked)
    }

    // MARK: - HealthKit Integration

    /// All habits linked to a HealthKit metric that are active
    var healthKitLinkedHabits: [Habit] {
        habits.filter { $0.isHealthKitLinked && $0.isActive }
    }

    /// Unique HealthKit metrics currently being tracked
    var activeHealthKitMetrics: [HealthKitMetricType] {
        Array(Set(healthKitLinkedHabits.compactMap { $0.healthKitMetric }))
    }

    /// Check all HealthKit habits and auto-complete if target reached
    /// - Parameter triggerNotification: Whether to send a notification (for background updates)
    func checkHealthKitCompletions(triggerNotification: Bool = false) {
        let today = Date()
        let healthKitManager = HealthKitManager.shared

        for habit in healthKitLinkedHabits {
            guard let metric = habit.healthKitMetric,
                  let target = habit.healthKitTarget,
                  habit.healthKitAutoComplete else { continue }

            let currentValue = healthKitManager.currentValues[metric] ?? 0

            // Check if target reached and not already completed
            if currentValue >= target && !habit.isCompleted(for: today) {
                autoCompleteHealthKitHabit(habit, value: currentValue, triggerNotification: triggerNotification)
            }
        }
    }

    /// Auto-complete a habit via HealthKit
    private func autoCompleteHealthKitHabit(_ habit: Habit, value: Double, triggerNotification: Bool) {
        let today = Date()

        // Create or update the log with auto-completion flag
        let log = DailyLog.createOrUpdate(
            for: habit,
            on: today,
            completed: true,
            value: value,
            context: modelContext
        )
        log.autoCompletedByHealthKit = true

        // Update streak
        updateStreak(for: habit)

        saveContext()

        // Send notification if app is backgrounded
        if triggerNotification {
            let isAppInBackground = UIApplication.shared.applicationState != .active
            if isAppInBackground, let metric = habit.healthKitMetric {
                HealthKitManager.shared.sendAchievementNotification(
                    habitName: habit.name,
                    metricType: metric,
                    value: value
                )
            }
        }

        // Refresh smart reminders since completion state changed
        refreshNotifications()

        // refreshNotifications() above already handles rescheduling
    }
}
