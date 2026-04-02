import Foundation
import UserNotifications

/// Unified notification service — auto-schedules one notification per habit per time slot.
///
/// Each habit gets notified at the time(s) matching its `scheduleTimes` assignment.
/// Times are configured globally per slot in Settings via `UserSchedule`.
///
/// Budget allocation (64 total):
/// - Habit slot notifications: 44 slots (repeating triggers count as 1)
/// - Task deadlines: 20 slots (up to 5 reminders x 4 tasks)
final class UnifiedNotificationService {
    static let shared = UnifiedNotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    // Notification identifier prefixes
    private let habitPrefix = "habit_"
    private let taskDeadlinePrefix = "task_deadline_"

    // Budget limits
    private let habitSlots = 44
    private let taskDeadlineSlots = 20

    private let schedule = UserSchedule.shared

    private init() {}

    // MARK: - Time Slot Mapping

    /// Maps a schedule time label to its UserSchedule slot index
    private func slotIndex(for scheduleTime: String) -> Int? {
        switch scheduleTime {
        case "After Wake": return 0
        case "Morning": return 1
        case "During the Day": return 2
        case "Evening": return 3
        case "Before Bed": return 4
        default: return nil
        }
    }

    /// Returns the notification time (minutes from midnight) for a schedule time label
    private func minutesForSlot(_ scheduleTime: String) -> Int {
        let slots = schedule.allReminderSlots
        if let index = slotIndex(for: scheduleTime), index < slots.count {
            return slots[index].minutes
        }
        // Fallback to wake time
        return schedule.wakeTimeMinutes
    }

    /// Returns whether a slot is enabled for notifications
    private func isSlotEnabled(_ scheduleTime: String) -> Bool {
        guard let index = slotIndex(for: scheduleTime) else { return true }
        return schedule.isSlotEnabled(index)
    }

    // MARK: - Schedule All Habit Notifications

    /// Reschedules all individual habit notifications based on time slot assignments.
    /// Call this when habits change, completions change, or notification settings change.
    func scheduleAllHabitNotifications(for habits: [Habit]) async {
        // Cancel existing habit notifications
        await cancelAllHabitNotifications()

        // Check master toggle
        guard schedule.notificationsEnabled else {
            print("[UnifiedNotification] Notifications disabled globally")
            return
        }

        // Check permission
        let status = await NotificationService.shared.checkPermissionStatus()
        guard status == .authorized else {
            print("[UnifiedNotification] Notification permission not authorized")
            return
        }

        let today = Date()

        // Filter to active, uncompleted, non-task, non-negative habits
        // Don't-do (negative) habits must never send reminders — reminding the user
        // about a distraction app makes them think about it
        let skippedNegative = habits.filter { $0.isActive && !$0.isTask && $0.type == .negative }
        for habit in skippedNegative {
            print("[UnifiedNotification] ⛔ Skipping don't-do habit: \(habit.name)")
        }

        let eligibleHabits = habits.filter {
            $0.isActive && !$0.isTask && !$0.isCompleted(for: today) && $0.type != .negative
        }

        var scheduledCount = 0

        for habit in eligibleHabits {
            print("[UnifiedNotification] ✅ Scheduling: \(habit.name)")
            guard scheduledCount < habitSlots else {
                print("[UnifiedNotification] Hit habit slot limit (\(habitSlots))")
                break
            }

            if habit.scheduleTimes.isEmpty {
                // No time slots assigned — notify at wake time as fallback
                await scheduleHabitNotification(for: habit, slotLabel: "After Wake", minutes: schedule.wakeTimeMinutes)
                scheduledCount += 1
            } else {
                // Schedule one notification per assigned time slot
                for slotLabel in habit.scheduleTimes {
                    guard scheduledCount < habitSlots else { break }
                    guard isSlotEnabled(slotLabel) else { continue }

                    let minutes = minutesForSlot(slotLabel)

                    switch habit.frequencyType {
                    case .daily:
                        await scheduleHabitNotification(for: habit, slotLabel: slotLabel, minutes: minutes)
                        scheduledCount += 1

                    case .weekly:
                        // Schedule only on selected days
                        let days = habit.weeklyNotificationDays.isEmpty ? Array(1...7) : habit.weeklyNotificationDays
                        for weekday in days {
                            guard scheduledCount < habitSlots else { break }
                            await scheduleWeeklyHabitNotification(for: habit, slotLabel: slotLabel, minutes: minutes, weekday: weekday)
                            scheduledCount += 1
                        }

                    case .once, .monthly:
                        break
                    }
                }
            }
        }

        print("[UnifiedNotification] Scheduled \(scheduledCount) habit notifications")
    }

    // MARK: - Individual Habit Notification

    /// Schedules a daily repeating notification for a habit at a specific time slot
    private func scheduleHabitNotification(for habit: Habit, slotLabel: String, minutes: Int) async {
        let identifier = "\(habitPrefix)\(habit.id.uuidString)_\(slotLabel)"

        let content = makeNotificationContent(for: habit)

        var dateComponents = DateComponents()
        dateComponents.hour = minutes / 60
        dateComponents.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
        } catch {
            print("[UnifiedNotification] Failed to schedule notification for \(habit.name): \(error)")
        }
    }

    /// Schedules a weekly notification for a habit at a specific time slot and weekday
    private func scheduleWeeklyHabitNotification(for habit: Habit, slotLabel: String, minutes: Int, weekday: Int) async {
        let identifier = "\(habitPrefix)\(habit.id.uuidString)_\(slotLabel)_day\(weekday)"

        let content = makeNotificationContent(for: habit)

        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = minutes / 60
        dateComponents.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
        } catch {
            print("[UnifiedNotification] Failed to schedule weekly notification for \(habit.name): \(error)")
        }
    }

    /// Creates notification content for a habit
    private func makeNotificationContent(for habit: Habit) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = habit.name

        if !habit.habitPrompt.isEmpty {
            content.body = habit.habitPrompt
        } else {
            content.body = "Time to: \(habit.name.lowercased())"
        }

        content.sound = .default
        content.categoryIdentifier = "HABIT_REMINDER"
        content.userInfo = [
            "habitId": habit.id.uuidString,
            "type": "habit"
        ]

        return content
    }

    // MARK: - Task Deadline Notifications

    /// Schedules reminder notifications for a task with a deadline
    /// Reminder algorithm:
    /// - >8 hours until deadline: every 2 hours
    /// - 4-8 hours: every hour
    /// - <4 hours: every 30 minutes
    /// - Stop 1 hour before deadline (final reminder)
    /// - Maximum 5 reminders per task
    func scheduleTaskDeadlineNotifications(for task: Habit) async {
        guard task.isTask,
              let deadlineMinutes = task.taskDeadlineMinutes else { return }

        // Cancel existing deadline notifications for this task
        await cancelTaskDeadlineNotifications(for: task)

        // Check permission
        let status = await NotificationService.shared.checkPermissionStatus()
        guard status == .authorized else { return }

        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        // Calculate deadline time
        guard let deadlineDate = calendar.date(
            byAdding: .minute,
            value: deadlineMinutes,
            to: today
        ) else { return }

        // If deadline has passed, don't schedule
        guard deadlineDate > now else { return }

        let minutesUntilDeadline = Int(deadlineDate.timeIntervalSince(now) / 60)

        // Generate reminder times
        var reminderMinutesFromNow: [Int] = []

        // Calculate reminder intervals
        if minutesUntilDeadline > 8 * 60 {
            var current = 0
            while current + 120 < minutesUntilDeadline - 8 * 60 {
                current += 120
                reminderMinutesFromNow.append(current)
            }
            current = minutesUntilDeadline - 8 * 60
            while current + 60 < minutesUntilDeadline - 4 * 60 {
                current += 60
                reminderMinutesFromNow.append(current)
            }
            current = minutesUntilDeadline - 4 * 60
            while current + 30 < minutesUntilDeadline - 60 {
                current += 30
                reminderMinutesFromNow.append(current)
            }
            reminderMinutesFromNow.append(minutesUntilDeadline - 60)

        } else if minutesUntilDeadline > 4 * 60 {
            var current = 0
            while current + 60 < minutesUntilDeadline - 60 {
                current += 60
                reminderMinutesFromNow.append(current)
            }
            reminderMinutesFromNow.append(minutesUntilDeadline - 60)

        } else if minutesUntilDeadline > 60 {
            var current = 0
            while current + 30 < minutesUntilDeadline - 60 {
                current += 30
                reminderMinutesFromNow.append(current)
            }
            reminderMinutesFromNow.append(minutesUntilDeadline - 60)

        } else {
            reminderMinutesFromNow.append(1)
        }

        // Limit to 5 reminders
        let remindersToSchedule = Array(reminderMinutesFromNow.prefix(5))

        for (index, minutesFromNow) in remindersToSchedule.enumerated() {
            let identifier = "\(taskDeadlinePrefix)\(task.id.uuidString)_\(index)"

            let content = UNMutableNotificationContent()
            content.title = "REMINDER"
            content.body = task.name
            content.sound = .default
            content.categoryIdentifier = "TASK_REMINDER"
            content.userInfo = [
                "habitId": task.id.uuidString,
                "type": "task"
            ]

            let remainingMinutes = minutesUntilDeadline - minutesFromNow
            if remainingMinutes >= 60 {
                let hours = remainingMinutes / 60
                content.body = "\(task.name) - \(hours) hour\(hours == 1 ? "" : "s") left"
            } else if remainingMinutes > 0 {
                content.body = "\(task.name) - \(remainingMinutes) min left"
            }

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: Double(minutesFromNow * 60),
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            do {
                try await notificationCenter.add(request)
            } catch {
                print("[UnifiedNotification] Failed to schedule task deadline notification: \(error)")
            }
        }

        print("[UnifiedNotification] Scheduled \(remindersToSchedule.count) deadline reminders for task: \(task.name)")
    }

    // MARK: - Cancellation

    /// Cancels all habit notifications
    func cancelAllHabitNotifications() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let habitIdentifiers = pending
            .filter { $0.identifier.hasPrefix(habitPrefix) }
            .map { $0.identifier }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: habitIdentifiers)
    }

    /// Cancels notifications for a specific habit
    func cancelNotifications(for habit: Habit) async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let identifiers = pending
            .filter { $0.identifier.hasPrefix("\(habitPrefix)\(habit.id.uuidString)") }
            .map { $0.identifier }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Cancels deadline notifications for a specific task
    func cancelTaskDeadlineNotifications(for task: Habit) async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let identifiers = pending
            .filter { $0.identifier.hasPrefix("\(taskDeadlinePrefix)\(task.id.uuidString)") }
            .map { $0.identifier }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Cancels all task deadline notifications
    func cancelAllTaskDeadlineNotifications() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let identifiers = pending
            .filter { $0.identifier.hasPrefix(taskDeadlinePrefix) }
            .map { $0.identifier }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Debugging

    /// Returns counts of scheduled notifications by category
    func getNotificationCounts() async -> (habits: Int, taskDeadlines: Int, other: Int) {
        let pending = await notificationCenter.pendingNotificationRequests()

        let habits = pending.filter { $0.identifier.hasPrefix(habitPrefix) }.count
        let taskDeadlines = pending.filter { $0.identifier.hasPrefix(taskDeadlinePrefix) }.count
        let other = pending.count - habits - taskDeadlines

        return (habits, taskDeadlines, other)
    }
}

// MARK: - Array Extension

extension Array {
    /// Splits array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
