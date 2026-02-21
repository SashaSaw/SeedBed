import Foundation
import UserNotifications

/// Unified notification service for individual habit/task reminders
///
/// Key features:
/// - Individual notifications per habit/hobby (not fat lists)
/// - Batching: max 3 notifications at a time, spaced 10 minutes apart
/// - Task deadline reminders with escalating frequency
/// - Budget management: 64 notification slots total
///
/// Budget allocation:
/// - Task deadlines: 20 slots (up to 5 reminders x 4 tasks)
/// - Individual habits: 35 slots (repeating triggers count as 1)
/// - Smart reminders: 5 slots
/// - Buffer: 4 slots
final class UnifiedNotificationService {
    static let shared = UnifiedNotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    // Notification identifier prefixes
    private let habitPrefix = "habit_"
    private let taskDeadlinePrefix = "task_deadline_"

    // Budget limits
    private let maxTotalNotifications = 64
    private let taskDeadlineSlots = 20
    private let habitSlots = 35
    private let smartReminderSlots = 5
    private let bufferSlots = 4

    // Batching configuration
    private let maxSimultaneousNotifications = 3
    private let batchIntervalMinutes = 10

    private init() {}

    // MARK: - Schedule All Habit Notifications

    /// Reschedules all individual habit notifications
    /// Call this when habits are added, modified, or at app launch
    /// Only schedules notifications for habits NOT completed today
    func scheduleAllHabitNotifications(for habits: [Habit]) async {
        // Cancel existing habit notifications
        await cancelAllHabitNotifications()

        // Check permission
        let status = await NotificationService.shared.checkPermissionStatus()
        guard status == .authorized else {
            print("[UnifiedNotification] Notification permission not authorized")
            return
        }

        let today = Date()

        // Filter to habits with notifications enabled AND not completed today
        let habitsWithNotifications = habits.filter {
            $0.notificationsEnabled && $0.isActive && !$0.isTask && !$0.isCompleted(for: today)
        }

        // Group habits by notification time
        var habitsByTime: [Int: [Habit]] = [:]

        for habit in habitsWithNotifications {
            switch habit.frequencyType {
            case .daily:
                for minutes in habit.dailyNotificationMinutes {
                    habitsByTime[minutes, default: []].append(habit)
                }
            case .weekly:
                // Weekly notifications use weeklyNotificationTime
                let minutes = habit.weeklyNotificationTime
                habitsByTime[minutes, default: []].append(habit)
            case .once, .monthly:
                break
            }
        }

        // Schedule with batching
        var scheduledCount = 0

        for (baseMinutes, habitsAtTime) in habitsByTime.sorted(by: { $0.key < $1.key }) {
            let batches = habitsAtTime.chunked(into: maxSimultaneousNotifications)

            for (batchIndex, batch) in batches.enumerated() {
                let offsetMinutes = batchIndex * batchIntervalMinutes
                let scheduledMinutes = baseMinutes + offsetMinutes

                for habit in batch {
                    guard scheduledCount < habitSlots else {
                        print("[UnifiedNotification] Hit habit slot limit (\(habitSlots))")
                        return
                    }

                    await scheduleIndividualHabitNotification(
                        for: habit,
                        at: scheduledMinutes
                    )
                    scheduledCount += 1
                }
            }
        }

        print("[UnifiedNotification] Scheduled \(scheduledCount) habit notifications")
    }

    // MARK: - Individual Habit Notification

    /// Schedules a single notification for a habit
    private func scheduleIndividualHabitNotification(for habit: Habit, at minutes: Int) async {
        let identifier = "\(habitPrefix)\(habit.id.uuidString)_\(minutes)"

        let content = UNMutableNotificationContent()
        content.title = "Reminder: \(habit.name)"

        // Use habit prompt if available, otherwise default message
        if !habit.habitPrompt.isEmpty {
            content.body = habit.habitPrompt
        } else {
            content.body = "Don't forget to \(habit.name.lowercased())"
        }

        content.sound = .default
        content.categoryIdentifier = "HABIT_REMINDER"
        content.userInfo = [
            "habitId": habit.id.uuidString,
            "type": "habit"
        ]

        // Create trigger based on frequency
        let trigger: UNNotificationTrigger

        switch habit.frequencyType {
        case .daily:
            var dateComponents = DateComponents()
            dateComponents.hour = minutes / 60
            dateComponents.minute = minutes % 60
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        case .weekly:
            // Schedule for each selected day of the week
            for weekday in habit.weeklyNotificationDays {
                var dateComponents = DateComponents()
                dateComponents.weekday = weekday
                dateComponents.hour = minutes / 60
                dateComponents.minute = minutes % 60

                let weeklyTrigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let weeklyIdentifier = "\(identifier)_day\(weekday)"

                let request = UNNotificationRequest(
                    identifier: weeklyIdentifier,
                    content: content,
                    trigger: weeklyTrigger
                )

                do {
                    try await notificationCenter.add(request)
                } catch {
                    print("[UnifiedNotification] Failed to schedule weekly notification: \(error)")
                }
            }
            return

        case .once, .monthly:
            return
        }

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("[UnifiedNotification] Failed to schedule habit notification: \(error)")
        }
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
            // More than 8 hours: every 2 hours until 8 hours remain
            var current = 0
            while current + 120 < minutesUntilDeadline - 8 * 60 {
                current += 120
                reminderMinutesFromNow.append(current)
            }
            // Then every hour from 8 hours to 4 hours
            current = minutesUntilDeadline - 8 * 60
            while current + 60 < minutesUntilDeadline - 4 * 60 {
                current += 60
                reminderMinutesFromNow.append(current)
            }
            // Then every 30 min from 4 hours to 1 hour
            current = minutesUntilDeadline - 4 * 60
            while current + 30 < minutesUntilDeadline - 60 {
                current += 30
                reminderMinutesFromNow.append(current)
            }
            // Final reminder at 1 hour before
            reminderMinutesFromNow.append(minutesUntilDeadline - 60)

        } else if minutesUntilDeadline > 4 * 60 {
            // 4-8 hours: every hour
            var current = 0
            while current + 60 < minutesUntilDeadline - 60 {
                current += 60
                reminderMinutesFromNow.append(current)
            }
            reminderMinutesFromNow.append(minutesUntilDeadline - 60)

        } else if minutesUntilDeadline > 60 {
            // 1-4 hours: every 30 min, stopping 1 hour before
            var current = 0
            while current + 30 < minutesUntilDeadline - 60 {
                current += 30
                reminderMinutesFromNow.append(current)
            }
            reminderMinutesFromNow.append(minutesUntilDeadline - 60)

        } else {
            // Less than 1 hour: just send one reminder now
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

            // Calculate remaining time for body
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
    func getNotificationCounts() async -> (habits: Int, taskDeadlines: Int, smartReminders: Int, other: Int) {
        let pending = await notificationCenter.pendingNotificationRequests()

        let habits = pending.filter { $0.identifier.hasPrefix(habitPrefix) }.count
        let taskDeadlines = pending.filter { $0.identifier.hasPrefix(taskDeadlinePrefix) }.count
        let smartReminders = pending.filter { $0.identifier.hasPrefix("smart_reminder_") }.count
        let other = pending.count - habits - taskDeadlines - smartReminders

        return (habits, taskDeadlines, smartReminders, other)
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
