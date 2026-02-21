import Foundation
import UserNotifications
import SwiftData

/// Manages the 5 daily smart reminders based on user schedule and habit state
///
/// Reminder schedule:
/// 1. Wake time — "Good morning! Start your morning habits"
/// 2. 11:00 AM — "Morning reminder: finish morning habits"
/// 3. 5:00 PM — "Afternoon check-in: get daytime habits done"
/// 4. 2hrs before bed — "Evening wind-down: finish hobbies"
/// 5. 1hr before bed — "Last call: finish before-bed habits"
final class SmartReminderService {
    static let shared = SmartReminderService()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let schedule = UserSchedule.shared

    // Notification identifier prefix for smart reminders
    private let identifierPrefix = "smart_reminder_"

    // Batching configuration (matches UnifiedNotificationService)
    private let maxHabitsPerBatch = 3
    private let batchIntervalMinutes = 10
    private let maxBatchesPerReminder = 10

    private init() {}

    // MARK: - Schedule All Smart Reminders

    /// Reschedules all 5 smart reminders based on current habits and schedule
    /// Call this when:
    /// - Smart reminders are toggled on
    /// - User changes wake/bed time
    /// - Habits are added/removed/modified
    /// - At midnight rollover
    func rescheduleAllReminders(habits: [Habit], groups: [HabitGroup]) async {
        // Cancel all existing smart reminders first
        await cancelAllSmartReminders()

        guard schedule.smartRemindersEnabled else {
            print("[SmartReminder] Smart reminders disabled — skipping")
            return
        }

        // Check permission
        let status = await NotificationService.shared.checkPermissionStatus()
        guard status == .authorized else {
            print("[SmartReminder] Notification permission not authorized (status: \(status.rawValue)) — skipping")
            return
        }

        let activeHabits = habits.filter { $0.isActive && !$0.isTask }
        print("[SmartReminder] Scheduling reminders for \(activeHabits.count) active habits, \(groups.count) groups")
        print("[SmartReminder] Wake: \(schedule.wakeTimeString), Bed: \(schedule.bedTimeString)")

        let today = Date()

        // Schedule each of the 5 reminders
        await scheduleReminder1_WakeUp(habits: habits, groups: groups, on: today)
        await scheduleReminder2_LateMorning(habits: habits, groups: groups, on: today)
        await scheduleReminder3_Afternoon(habits: habits, groups: groups, on: today)
        await scheduleReminder4_Evening(habits: habits, groups: groups, on: today)
        await scheduleReminder5_BeforeBed(habits: habits, groups: groups, on: today)
    }

    // MARK: - Individual Reminders

    /// Reminder 1: Wake time — "Good morning! Start your morning habits"
    private func scheduleReminder1_WakeUp(habits: [Habit], groups: [HabitGroup], on date: Date) async {
        let afterWakeHabits = habitsForTimeSlot("After Wake", from: habits, groups: groups, on: date)
        let uncompletedHabits = afterWakeHabits.filter { !$0.isCompleted(for: date) }
        let uncompletedTasks = todayTasks(from: habits, on: date)

        guard !uncompletedHabits.isEmpty || !uncompletedTasks.isEmpty else { return }

        // Combine habits and tasks for batching
        let allItems = uncompletedHabits + uncompletedTasks
        let batches = allItems.chunked(into: maxHabitsPerBatch)
        let baseMinutes = schedule.reminder1Minutes

        for (batchIndex, batch) in batches.enumerated() {
            let offsetMinutes = batchIndex * batchIntervalMinutes
            let (title, body) = formatBatchNotification(
                batch: batch,
                baseTitle: "Rise and shine ☀️",
                context: "Good morning!",
                batchIndex: batchIndex,
                totalBatches: batches.count
            )

            await scheduleNotification(
                index: 0,
                batchIndex: batchIndex,
                minutes: baseMinutes + offsetMinutes,
                title: title,
                body: body
            )
        }
    }

    /// Reminder 2: 11:00 AM — "Morning reminder: you still have X morning habits left"
    private func scheduleReminder2_LateMorning(habits: [Habit], groups: [HabitGroup], on date: Date) async {
        let morningHabits = habitsForTimeSlot("Morning", from: habits, groups: groups, on: date)
            + habitsForTimeSlot("After Wake", from: habits, groups: groups, on: date)
        let uncompletedHabits = morningHabits.filter { !$0.isCompleted(for: date) }
        let uncompletedTasks = todayTasks(from: habits, on: date)

        guard !uncompletedHabits.isEmpty || !uncompletedTasks.isEmpty else { return }

        // Combine habits and tasks for batching
        let allItems = uncompletedHabits + uncompletedTasks
        let batches = allItems.chunked(into: maxHabitsPerBatch)
        let baseMinutes = schedule.reminder2Minutes

        for (batchIndex, batch) in batches.enumerated() {
            let offsetMinutes = batchIndex * batchIntervalMinutes
            let (title, body) = formatBatchNotification(
                batch: batch,
                baseTitle: "Morning check-in 🌤️",
                context: "Still to do",
                batchIndex: batchIndex,
                totalBatches: batches.count
            )

            await scheduleNotification(
                index: 1,
                batchIndex: batchIndex,
                minutes: baseMinutes + offsetMinutes,
                title: title,
                body: body
            )
        }
    }

    /// Reminder 3: 5:00 PM — "Afternoon check-in: get your daytime habits done"
    private func scheduleReminder3_Afternoon(habits: [Habit], groups: [HabitGroup], on date: Date) async {
        let daytimeHabits = habitsForTimeSlot("During the Day", from: habits, groups: groups, on: date)
        let uncompletedHabits = daytimeHabits.filter { !$0.isCompleted(for: date) }
        let uncompletedTasks = todayTasks(from: habits, on: date)

        guard !uncompletedHabits.isEmpty || !uncompletedTasks.isEmpty else { return }

        // Combine habits and tasks for batching
        let allItems = uncompletedHabits + uncompletedTasks
        let batches = allItems.chunked(into: maxHabitsPerBatch)
        let baseMinutes = schedule.reminder3Minutes

        for (batchIndex, batch) in batches.enumerated() {
            let offsetMinutes = batchIndex * batchIntervalMinutes
            let (title, body) = formatBatchNotification(
                batch: batch,
                baseTitle: "Afternoon check-in 📋",
                context: "Time to finish up",
                batchIndex: batchIndex,
                totalBatches: batches.count
            )

            await scheduleNotification(
                index: 2,
                batchIndex: batchIndex,
                minutes: baseMinutes + offsetMinutes,
                title: title,
                body: body
            )
        }
    }

    /// Reminder 4: 2hrs before bed — "Evening wind-down: finish your hobbies"
    private func scheduleReminder4_Evening(habits: [Habit], groups: [HabitGroup], on date: Date) async {
        let eveningHabits = habitsForTimeSlot("Evening", from: habits, groups: groups, on: date)
        let uncompleted = eveningHabits.filter { !$0.isCompleted(for: date) }
        let uncompletedTasks = todayTasks(from: habits, on: date)

        // Also include uncompleted nice-to-do hobbies scheduled for Evening
        let eveningNiceToDos = habits.filter { habit in
            habit.isActive && !habit.isTask && habit.tier == .niceToDo &&
            !habit.isCompleted(for: date) && habit.groupId == nil &&
            (habit.scheduleTimes.isEmpty || habit.scheduleTimes.contains("Evening"))
        }

        let combined = Array(Set(uncompleted.map(\.id)).union(eveningNiceToDos.map(\.id)))
            .compactMap { id in habits.first(where: { $0.id == id }) }

        guard !combined.isEmpty || !uncompletedTasks.isEmpty else { return }

        // Combine habits and tasks for batching
        let allItems = combined + uncompletedTasks
        let batches = allItems.chunked(into: maxHabitsPerBatch)
        let baseMinutes = schedule.reminder4Minutes

        for (batchIndex, batch) in batches.enumerated() {
            let offsetMinutes = batchIndex * batchIntervalMinutes
            let (title, body) = formatBatchNotification(
                batch: batch,
                baseTitle: "Evening wind-down 🌙",
                context: "Wind down time",
                batchIndex: batchIndex,
                totalBatches: batches.count,
                usePrompts: true
            )

            await scheduleNotification(
                index: 3,
                batchIndex: batchIndex,
                minutes: baseMinutes + offsetMinutes,
                title: title,
                body: body
            )
        }
    }

    /// Reminder 5: 1hr before bed — "Last call: finish your before-bed habits"
    private func scheduleReminder5_BeforeBed(habits: [Habit], groups: [HabitGroup], on date: Date) async {
        let beforeBedHabits = habitsForTimeSlot("Before Bed", from: habits, groups: groups, on: date)
        let uncompleted = beforeBedHabits.filter { !$0.isCompleted(for: date) }

        guard !uncompleted.isEmpty else { return }

        let batches = uncompleted.chunked(into: maxHabitsPerBatch)
        let baseMinutes = schedule.reminder5Minutes

        for (batchIndex, batch) in batches.enumerated() {
            let offsetMinutes = batchIndex * batchIntervalMinutes
            let (title, body) = formatBatchNotification(
                batch: batch,
                baseTitle: "Almost bedtime 😴",
                context: "Last call",
                batchIndex: batchIndex,
                totalBatches: batches.count
            )

            await scheduleNotification(
                index: 4,
                batchIndex: batchIndex,
                minutes: baseMinutes + offsetMinutes,
                title: title,
                body: body
            )
        }
    }

    // MARK: - Notification Scheduling

    private func scheduleNotification(index: Int, batchIndex: Int, minutes: Int, title: String, body: String) async {
        let identifier = "\(identifierPrefix)\(index)_batch_\(batchIndex)"

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "SMART_REMINDER"

        // Calculate if the target time is still in the future today
        let calendar = Calendar.current
        let now = Date()
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        let trigger: UNNotificationTrigger
        if minutes > currentMinutes {
            // Time is still ahead today — use a time interval for reliable same-day delivery
            let secondsUntil = Double((minutes - currentMinutes) * 60)
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(secondsUntil, 5), repeats: false)
            print("[SmartReminder] Scheduling reminder \(index) batch \(batchIndex) in \(Int(secondsUntil/60)) minutes (today)")
        } else {
            // Time has passed today — schedule as daily repeating for tomorrow onwards
            var dateComponents = DateComponents()
            dateComponents.hour = minutes / 60
            dateComponents.minute = minutes % 60
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            print("[SmartReminder] Scheduling reminder \(index) batch \(batchIndex) as daily repeating at \(minutes/60):\(String(format: "%02d", minutes%60))")
        }

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("[SmartReminder] ✅ Reminder \(index) batch \(batchIndex) scheduled: \(title)")
        } catch {
            print("[SmartReminder] ❌ Failed to schedule reminder \(index) batch \(batchIndex): \(error)")
        }
    }

    // MARK: - Cancellation

    /// Cancel all smart reminders (5 reminders × up to maxBatchesPerReminder batches each)
    func cancelAllSmartReminders() async {
        var identifiers: [String] = []
        for reminderIndex in 0..<5 {
            for batchIndex in 0..<maxBatchesPerReminder {
                identifiers.append("\(identifierPrefix)\(reminderIndex)_batch_\(batchIndex)")
            }
            // Also cancel legacy non-batched identifiers for backwards compatibility
            identifiers.append("\(identifierPrefix)\(reminderIndex)")
        }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Helpers

    /// Get habits for a specific time slot that are must-dos or standalone nice-to-dos (not group members)
    /// If a habit has no scheduleTimes at all, it's treated as belonging to ALL slots (backwards compatible)
    private func habitsForTimeSlot(_ slotRawValue: String, from habits: [Habit], groups: [HabitGroup], on date: Date) -> [Habit] {
        let groupedHabitIds = Set(groups.filter { $0.tier == .mustDo }.flatMap { $0.habitIds })

        return habits.filter { habit in
            guard habit.isActive && !habit.isTask else { return false }

            // If habit has no schedule times set, include it in all slots (backwards compatible)
            // Otherwise check if it belongs to the requested slot
            let matchesSlot = habit.scheduleTimes.isEmpty || habit.scheduleTimes.contains(slotRawValue)
            guard matchesSlot else { return false }

            // Include must-dos (standalone only) and standalone nice-to-dos
            if habit.tier == .mustDo && !groupedHabitIds.contains(habit.id) {
                return true
            }
            if habit.tier == .niceToDo && habit.groupId == nil {
                return true
            }

            return false
        }
    }

    /// Get uncompleted tasks for today (habits with frequencyType == .once, created today)
    private func todayTasks(from habits: [Habit], on date: Date) -> [Habit] {
        let calendar = Calendar.current
        return habits.filter { habit in
            guard habit.isTask && habit.isActive else { return false }
            guard !habit.isCompleted(for: date) else { return false }
            // Only include tasks created today
            return calendar.isDate(habit.createdAt, inSameDayAs: date)
        }
    }

    /// Display name for a habit (strip emoji prefix if present)
    private func displayName(for habit: Habit) -> String {
        // The habit name may have emoji prefix like "💧 Drink enough water"
        // Just use the full name — it's already descriptive
        habit.name
    }

    /// Display name with habit prompt for hobbies (used in evening reminder)
    private func displayNameWithPrompt(for habit: Habit) -> String {
        if !habit.habitPrompt.isEmpty {
            return habit.habitPrompt
        }
        return habit.name
    }

    /// Count total must-do items (standalone + groups)
    private func mustDoTotal(habits: [Habit], groups: [HabitGroup]) -> Int {
        let mustDoHabits = habits.filter { $0.tier == .mustDo && !$0.isTask && $0.isActive }
        let mustDoGroups = groups.filter { $0.tier == .mustDo }
        let groupedHabitIds = Set(mustDoGroups.flatMap { $0.habitIds })
        let standalone = mustDoHabits.filter { !groupedHabitIds.contains($0.id) && $0.type == .positive }
        return standalone.count + mustDoGroups.count
    }

    /// Count completed must-do items
    private func mustDoCompleted(habits: [Habit], groups: [HabitGroup], on date: Date) -> Int {
        let mustDoHabits = habits.filter { $0.tier == .mustDo && !$0.isTask && $0.isActive }
        let mustDoGroups = groups.filter { $0.tier == .mustDo }
        let groupedHabitIds = Set(mustDoGroups.flatMap { $0.habitIds })
        let standalone = mustDoHabits.filter { !groupedHabitIds.contains($0.id) && $0.type == .positive }
        let completedStandalone = standalone.filter { $0.isCompleted(for: date) }.count
        let completedGroups = mustDoGroups.filter { $0.isSatisfied(habits: habits, for: date) }.count
        return completedStandalone + completedGroups
    }

    // MARK: - Batch Formatting

    /// Formats a batch of habits into an actionable notification
    /// - Parameters:
    ///   - batch: The habits in this batch
    ///   - baseTitle: The emoji title for this reminder type
    ///   - context: Contextual prefix for the body
    ///   - batchIndex: Which batch this is (0-indexed)
    ///   - totalBatches: Total number of batches
    ///   - usePrompts: Whether to use habit prompts instead of names (for evening reminder)
    /// - Returns: Tuple of (title, body) for the notification
    private func formatBatchNotification(
        batch: [Habit],
        baseTitle: String,
        context: String,
        batchIndex: Int,
        totalBatches: Int,
        usePrompts: Bool = false
    ) -> (title: String, body: String) {
        let title: String
        let body: String

        if batch.count == 1 {
            // Single habit: feature it prominently
            let habit = batch[0]
            let name = usePrompts ? displayNameWithPrompt(for: habit) : displayName(for: habit)
            title = "Time for \(habit.name)"
            if !habit.habitPrompt.isEmpty {
                body = habit.habitPrompt
            } else {
                body = "\(context) — \(name)"
            }
        } else {
            // Multiple habits: list them
            let names = batch.map { usePrompts ? displayNameWithPrompt(for: $0) : displayName(for: $0) }
            let habitList = names.joined(separator: ", ")

            if totalBatches > 1 {
                title = "\(baseTitle) (\(batchIndex + 1)/\(totalBatches))"
            } else {
                title = baseTitle
            }

            body = "\(habitList) — \(batch.count) habit\(batch.count == 1 ? "" : "s") to go!"
        }

        return (title, body)
    }
}
