import SwiftUI

/// Reusable card showing smart reminder settings
/// Used in onboarding ScheduleScreen and in the main app settings
struct SmartReminderSettingsCard: View {
    @State private var schedule = UserSchedule.shared
    @State private var editingReminderIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "bell.badge")
                    .font(.custom("PatrickHand-Regular", size: 18))
                    .foregroundStyle(JournalTheme.Colors.amber)

                Text("Smart Reminders")
                    .font(.custom("PatrickHand-Regular", size: 17))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                Spacer()

                Toggle("", isOn: $schedule.smartRemindersEnabled)
                    .tint(JournalTheme.Colors.amber)
                    .labelsHidden()
                    .onChange(of: schedule.smartRemindersEnabled) { _, _ in
                        Feedback.selection()
                    }
            }

            if schedule.smartRemindersEnabled {
                // Explanation
                Text("Tap a reminder to change its time.")
                    .font(.custom("PatrickHand-Regular", size: 13))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .fixedSize(horizontal: false, vertical: true)

                // Reminder timeline
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(schedule.allReminderSlots.enumerated()), id: \.offset) { index, slot in
                        VStack(alignment: .leading, spacing: 0) {
                            reminderRow(
                                number: index + 1,
                                time: formatMinutes(slot.minutes),
                                label: slot.label,
                                description: reminderDescription(for: index),
                                isEditing: editingReminderIndex == index,
                                hasOverride: schedule.hasOverride(for: index)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Feedback.selection()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    editingReminderIndex = editingReminderIndex == index ? nil : index
                                }
                            }

                            // Expanded time picker
                            if editingReminderIndex == index {
                                VStack(spacing: 8) {
                                    DatePicker(
                                        "Time",
                                        selection: reminderBinding(for: index),
                                        displayedComponents: .hourAndMinute
                                    )
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .frame(height: 120)

                                    if schedule.hasOverride(for: index) {
                                        Button {
                                            Feedback.selection()
                                            schedule.resetReminderToDefault(index)
                                            NotificationCenter.default.post(name: .smartRemindersChanged, object: nil)
                                        } label: {
                                            Text("Reset to default (\(formatMinutes(schedule.defaultMinutes(for: index))))")
                                                .font(.custom("PatrickHand-Regular", size: 13))
                                                .foregroundStyle(JournalTheme.Colors.amber)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.leading, 88)
                                .padding(.top, 4)
                                .padding(.bottom, 8)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JournalTheme.Colors.paperLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
        )
        .onChange(of: schedule.smartRemindersEnabled) { _, newValue in
            if !newValue {
                Task {
                    await SmartReminderService.shared.cancelAllSmartReminders()
                }
            }
        }
    }

    // MARK: - Row

    private func reminderRow(number: Int, time: String, label: String, description: String, isEditing: Bool, hasOverride: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Time badge
            HStack(spacing: 4) {
                Text(time)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(isEditing ? JournalTheme.Colors.inkBlue : JournalTheme.Colors.amber)
                if hasOverride {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(JournalTheme.Colors.amber)
                }
            }
            .frame(width: 76, alignment: .trailing)

            // Dot connector
            Circle()
                .fill(isEditing ? JournalTheme.Colors.inkBlue : JournalTheme.Colors.amber)
                .frame(width: 8, height: 8)
                .padding(.top, 4)

            // Description
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.custom("PatrickHand-Regular", size: 14))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                Text(description)
                    .font(.custom("PatrickHand-Regular", size: 12))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: isEditing ? "chevron.up" : "chevron.down")
                .font(.system(size: 10))
                .foregroundStyle(JournalTheme.Colors.completedGray)
                .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private func reminderBinding(for index: Int) -> Binding<Date> {
        Binding<Date>(
            get: {
                let minutes = schedule.allReminderSlots[index].minutes
                return Calendar.current.date(from: DateComponents(hour: minutes / 60, minute: minutes % 60)) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
                schedule.setReminderOverride(index, minutes: minutes)
                NotificationCenter.default.post(name: .smartRemindersChanged, object: nil)
            }
        )
    }

    private func reminderDescription(for index: Int) -> String {
        switch index {
        case 0: return "Write any tasks and start morning habits"
        case 1: return "Reminder to complete morning habits"
        case 2: return "Check-in on daytime habits"
        case 3: return "Finish hobbies and evening habits"
        case 4: return "Final habits before winding down"
        default: return ""
        }
    }

    private func formatMinutes(_ totalMinutes: Int) -> String {
        let hour = totalMinutes / 60
        let minute = totalMinutes % 60
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
}
