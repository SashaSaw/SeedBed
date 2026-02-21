import SwiftUI
import SwiftData

/// Simple today-only task creation — just a title, that's it.
struct AddTodayTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: HabitStore

    @State private var name = ""
    @State private var showConfirmation = false
    @State private var addedTaskName = ""
    @State private var hasDeadline = false
    @State private var deadlineTime = Date()

    @FocusState private var nameFieldFocused: Bool

    private var hasName: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Quick-pick suggestions for common one-off tasks
    private let taskSuggestions: [(emoji: String, name: String)] = [
        ("📞", "Make a call"),
        ("📦", "Pick up package"),
        ("🛒", "Grocery shop"),
        ("📧", "Reply to emails"),
        ("🧹", "Clean the house"),
        ("💇", "Haircut"),
        ("🏦", "Bank errand"),
        ("📝", "Fill out form"),
        ("🎁", "Buy a gift"),
    ]

    var body: some View {
        if showConfirmation {
            AddHabitConfirmationView(habitName: addedTaskName) { dismiss() }
        } else {
            formContent
        }
    }

    // MARK: - Form Content

    private var formContent: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    nameInputField

                    if !hasName {
                        quickPicksSection
                    }

                    if hasName {
                        deadlineSection
                        submitButton
                    }

                    Spacer(minLength: 60)
                }
                .padding(20)
            }
            .linedPaperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(JournalTheme.Colors.paper, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { Feedback.buttonPress(); dismiss() }
                        .foregroundStyle(JournalTheme.Colors.inkBlue)
                }
            }
        }
        .onAppear { nameFieldFocused = true }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("New today task")
                .font(JournalTheme.Fonts.title())
                .foregroundStyle(JournalTheme.Colors.teal)

            Text("A one-off task just for today")
                .font(JournalTheme.Fonts.habitCriteria())
                .foregroundStyle(JournalTheme.Colors.completedGray)
                .italic()
        }
    }

    // MARK: - Name Input

    private var nameInputField: some View {
        TextField("What do you need to do?", text: $name)
            .font(JournalTheme.Fonts.habitName())
            .foregroundStyle(JournalTheme.Colors.inkBlack)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(JournalTheme.Colors.paperLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
                    )
            )
            .focused($nameFieldFocused)
            .submitLabel(.done)
            .onSubmit { if hasName { addTask() } }
    }

    // MARK: - Quick Picks

    private var quickPicksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK PICKS")
                .font(JournalTheme.Fonts.sectionHeader())
                .foregroundStyle(JournalTheme.Colors.completedGray)
                .tracking(1.5)

            FlowLayout(spacing: 10) {
                ForEach(taskSuggestions, id: \.name) { suggestion in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            name = suggestion.emoji + " " + suggestion.name
                        }
                        Feedback.selection()
                    } label: {
                        HStack(spacing: 6) {
                            Text(suggestion.emoji)
                                .font(.custom("PatrickHand-Regular", size: 15))
                            Text(suggestion.name)
                                .font(JournalTheme.Fonts.habitCriteria())
                                .foregroundStyle(JournalTheme.Colors.inkBlack)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.85))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Deadline Section

    private var deadlineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Toggle for deadline
            HStack {
                Image(systemName: "clock.fill")
                    .font(.custom("PatrickHand-Regular", size: 14))
                    .foregroundStyle(JournalTheme.Colors.amber)
                    .frame(width: 24)

                Text("Set deadline")
                    .font(JournalTheme.Fonts.habitName())
                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                Spacer()

                Toggle("", isOn: $hasDeadline)
                    .labelsHidden()
                    .tint(JournalTheme.Colors.amber)
                    .onChange(of: hasDeadline) { _, newValue in
                        Feedback.selection()
                        if newValue {
                            // Default to 2 hours from now
                            deadlineTime = Date().addingTimeInterval(2 * 60 * 60)
                        }
                    }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            )

            // Time picker (shown when deadline is enabled)
            if hasDeadline {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Due by")
                        .font(JournalTheme.Fonts.sectionHeader())
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                        .tracking(1.5)

                    DatePicker(
                        "",
                        selection: $deadlineTime,
                        in: Date()...,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.7))
                    )

                    // Show time until deadline
                    let minutesUntil = Int(deadlineTime.timeIntervalSince(Date()) / 60)
                    if minutesUntil > 0 {
                        HStack {
                            Image(systemName: "bell.fill")
                                .font(.custom("PatrickHand-Regular", size: 12))
                                .foregroundStyle(JournalTheme.Colors.amber)

                            if minutesUntil >= 60 {
                                let hours = minutesUntil / 60
                                let mins = minutesUntil % 60
                                if mins > 0 {
                                    Text("Reminders will be sent over the next \(hours)h \(mins)m")
                                        .font(JournalTheme.Fonts.habitCriteria())
                                        .foregroundStyle(JournalTheme.Colors.completedGray)
                                } else {
                                    Text("Reminders will be sent over the next \(hours) hour\(hours == 1 ? "" : "s")")
                                        .font(JournalTheme.Fonts.habitCriteria())
                                        .foregroundStyle(JournalTheme.Colors.completedGray)
                                }
                            } else {
                                Text("Reminder will be sent shortly")
                                    .font(JournalTheme.Fonts.habitCriteria())
                                    .foregroundStyle(JournalTheme.Colors.completedGray)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button { addTask() } label: {
            Text("Add Task")
                .font(.custom("PatrickHand-Regular", size: 17))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(JournalTheme.Colors.teal)
                )
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Add Task Logic

    private func addTask() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        // Strip emoji for display name
        var displayName = trimmedName
        if let first = displayName.first, first.isEmoji {
            displayName = String(displayName.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        addedTaskName = displayName.isEmpty ? trimmedName : displayName

        // Calculate deadline minutes from midnight if set
        var deadlineMinutes: Int? = nil
        if hasDeadline {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: deadlineTime)
            let minute = calendar.component(.minute, from: deadlineTime)
            deadlineMinutes = hour * 60 + minute
        }

        let task = store.addHabit(
            name: trimmedName,
            frequencyType: .once,
            taskDeadlineMinutes: deadlineMinutes
        )

        // Schedule deadline notifications if deadline is set
        if deadlineMinutes != nil {
            Task {
                await UnifiedNotificationService.shared.scheduleTaskDeadlineNotifications(for: task)
            }
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            showConfirmation = true
        }
    }
}

#Preview("Add Today Task") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Habit.self, HabitGroup.self, DailyLog.self, configurations: config)
    let store = HabitStore(modelContext: container.mainContext)

    return AddTodayTaskView(store: store)
}
