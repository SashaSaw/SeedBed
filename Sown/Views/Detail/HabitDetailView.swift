import SwiftUI
import SwiftData

/// Redesigned detail view for a single habit — settings-row layout
struct HabitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: HabitStore
    let habit: Habit

    @State private var showingDeleteConfirmation = false
    @State private var editingName = false
    @State private var editedName: String = ""
    @State private var editingCriteria = false
    @State private var editedCriteria: [CriterionEntry] = [CriterionEntry()]
    @State private var showTimeSlots = false
    @State private var showFrequencyEditor = false
    @State private var editingPrompt = false
    @State private var editedPrompt: String = ""
    @State private var showHealthKitEditor = false
    @State private var healthKitManager = HealthKitManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Header
                VStack(alignment: .center, spacing: 12) {
                    // Icon
                    habitIcon

                    // Editable name
                    if editingName {
                        HStack {
                            TextField("Habit name", text: $editedName)
                                .font(.custom("PatrickHand-Regular", size: 22))
                                .foregroundStyle(JournalTheme.Colors.inkBlack)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(.plain)

                            Button("Save") {
                                Feedback.buttonPress()
                                habit.name = editedName.trimmingCharacters(in: .whitespaces)
                                store.updateHabit(habit)
                                editingName = false
                            }
                            .font(.custom("PatrickHand-Regular", size: 14))
                            .foregroundStyle(JournalTheme.Colors.teal)
                        }
                        .padding(.horizontal)
                    } else {
                        Text(habit.name)
                            .font(.custom("PatrickHand-Regular", size: 22))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)
                            .onTapGesture {
                                Feedback.selection()
                                editedName = habit.name
                                editingName = true
                            }
                    }

                    // Badges
                    HStack(spacing: 8) {
                        Text(habit.tier.displayName.uppercased())
                            .font(.custom("PatrickHand-Regular", size: 10))
                            .foregroundStyle(habit.tier == .mustDo ? JournalTheme.Colors.amber : JournalTheme.Colors.completedGray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(habit.tier == .mustDo ? JournalTheme.Colors.amber.opacity(0.12) : JournalTheme.Colors.lineLight.opacity(0.5))
                            )

                        Text(habit.frequencyDisplayName.uppercased())
                            .font(.custom("PatrickHand-Regular", size: 10))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(JournalTheme.Colors.lineLight.opacity(0.5))
                            )

                        if habit.type == .negative {
                            Text("QUIT")
                                .font(.custom("PatrickHand-Regular", size: 10))
                                .foregroundStyle(JournalTheme.Colors.coral)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(JournalTheme.Colors.coral.opacity(0.12))
                                )
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                // MARK: - Stats Cards
                HabitStatsSection(habit: habit, store: store)

                // MARK: - Recent Activity
                RecentActivitySection(habit: habit)

                // MARK: - Hobby Logs
                if habit.isHobby || habit.enableNotesPhotos {
                    HobbyLogsSection(habit: habit, store: store)
                }

                // MARK: - Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("SETTINGS")
                        .font(JournalTheme.Fonts.sectionHeader())
                        .foregroundStyle(JournalTheme.Colors.sectionHeader)
                        .tracking(2)

                    VStack(spacing: 0) {
                        // Priority
                        settingsRow(
                            icon: "star.fill",
                            iconColor: JournalTheme.Colors.amber,
                            label: "Priority",
                            value: habit.tier.displayName
                        ) {
                            Feedback.selection()
                            if habit.tier == .mustDo {
                                // Switching to nice-to-do: if daily, change to weekly 1x
                                habit.tier = .niceToDo
                                if habit.frequencyType == .daily {
                                    habit.frequencyType = .weekly
                                    habit.frequencyTarget = 1
                                }
                            } else {
                                // Switching to must-do: if not daily, change to daily
                                habit.tier = .mustDo
                                if habit.frequencyType != .daily {
                                    habit.frequencyType = .daily
                                    habit.frequencyTarget = 1
                                }
                            }
                            store.updateHabit(habit)
                        }

                        Divider().padding(.leading, 48)

                        // Frequency
                        settingsRow(
                            icon: "repeat",
                            iconColor: JournalTheme.Colors.teal,
                            label: "Frequency",
                            value: habit.frequencyDisplayName
                        ) {
                            Feedback.selection()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showFrequencyEditor.toggle()
                            }
                        }

                        // Inline frequency editor
                        if showFrequencyEditor && habit.frequencyType != .once {
                            VStack(alignment: .leading, spacing: 10) {
                                Picker("Frequency", selection: Binding(
                                    get: { habit.frequencyType },
                                    set: { newValue in
                                        Feedback.selection()
                                        habit.frequencyType = newValue
                                        if newValue == .daily {
                                            // Daily frequency → must be must-do
                                            habit.frequencyTarget = 1
                                            habit.tier = .mustDo
                                        } else if habit.tier == .mustDo {
                                            // Non-daily AND was must-do → switch to nice-to-do
                                            habit.tier = .niceToDo
                                            if newValue == .weekly && habit.frequencyTarget > 7 {
                                                habit.frequencyTarget = 1
                                            }
                                        }
                                        store.updateHabit(habit)
                                    }
                                )) {
                                    ForEach(FrequencyType.recurringCases, id: \.self) { freq in
                                        Text(freq.displayName).tag(freq)
                                    }
                                }
                                .pickerStyle(.segmented)

                                if habit.frequencyType == .weekly {
                                    Stepper(
                                        "Target: \(habit.frequencyTarget)x per week",
                                        value: Binding(
                                            get: { habit.frequencyTarget },
                                            set: { Feedback.selection(); habit.frequencyTarget = $0; store.updateHabit(habit) }
                                        ),
                                        in: 1...7
                                    )
                                    .font(.custom("PatrickHand-Regular", size: 14))
                                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                                } else if habit.frequencyType == .monthly {
                                    Stepper(
                                        "Target: \(habit.frequencyTarget)x per month",
                                        value: Binding(
                                            get: { habit.frequencyTarget },
                                            set: { Feedback.selection(); habit.frequencyTarget = $0; store.updateHabit(habit) }
                                        ),
                                        in: 1...31
                                    )
                                    .font(.custom("PatrickHand-Regular", size: 14))
                                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 14)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Divider().padding(.leading, 48)

                        // Reminders
                        settingsRow(
                            icon: "bell.fill",
                            iconColor: JournalTheme.Colors.amber,
                            label: "Reminders",
                            value: habit.notificationsEnabled ? "On" : "Off"
                        ) {
                            habit.notificationsEnabled.toggle()
                            store.updateHabit(habit)
                            Feedback.selection()
                        }

                        Divider().padding(.leading, 48)

                        // Notes & Photos toggle
                        HStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.custom("PatrickHand-Regular", size: 14))
                                .foregroundStyle(JournalTheme.Colors.teal)
                                .frame(width: 24)

                            Text("Notes & photos")
                                .font(JournalTheme.Fonts.habitName())
                                .foregroundStyle(JournalTheme.Colors.inkBlack)

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { habit.enableNotesPhotos },
                                set: { newValue in
                                    Feedback.selection()
                                    habit.enableNotesPhotos = newValue
                                    habit.isHobby = newValue
                                    store.updateHabit(habit)
                                }
                            ))
                            .labelsHidden()
                            .tint(JournalTheme.Colors.teal)
                        }
                        .padding(14)

                        Divider().padding(.leading, 48)

                        // Habit prompt — shown for all habits
                        if editingPrompt {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.custom("PatrickHand-Regular", size: 14))
                                    .foregroundStyle(JournalTheme.Colors.amber)
                                    .frame(width: 24)

                                TextField("e.g. Put on your trainers and step outside", text: $editedPrompt)
                                    .font(.custom("PatrickHand-Regular", size: 14))
                                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                                    .textFieldStyle(.plain)

                                Button("Save") {
                                    Feedback.buttonPress()
                                    habit.habitPrompt = editedPrompt.trimmingCharacters(in: .whitespaces)
                                    store.updateHabit(habit)
                                    editingPrompt = false
                                }
                                .font(.custom("PatrickHand-Regular", size: 14))
                                .foregroundStyle(JournalTheme.Colors.teal)
                            }
                            .padding(14)
                        } else {
                            settingsRow(
                                icon: "sparkles",
                                iconColor: JournalTheme.Colors.amber,
                                label: "Habit prompt",
                                value: habit.habitPrompt.isEmpty ? "Not set" : habit.habitPrompt
                            ) {
                                Feedback.selection()
                                editedPrompt = habit.habitPrompt
                                editingPrompt = true
                            }
                        }

                        Divider().padding(.leading, 48)

                        // Success Criteria — structured editor
                        if editingCriteria {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    Image(systemName: "target")
                                        .font(.custom("PatrickHand-Regular", size: 14))
                                        .foregroundStyle(JournalTheme.Colors.successGreen)
                                        .frame(width: 24)

                                    Text("Success criteria")
                                        .font(.custom("PatrickHand-Regular", size: 14))
                                        .foregroundStyle(JournalTheme.Colors.inkBlack)

                                    Spacer()

                                    Button("Save") {
                                        Feedback.buttonPress()
                                        let criteriaString = CriteriaEditorView.buildCriteriaString(from: editedCriteria)
                                        habit.successCriteria = criteriaString.isEmpty ? nil : criteriaString
                                        store.updateHabit(habit)
                                        editingCriteria = false
                                    }
                                    .font(.custom("PatrickHand-Regular", size: 14))
                                    .foregroundStyle(JournalTheme.Colors.teal)
                                }

                                CriteriaEditorView(criteria: $editedCriteria)
                            }
                            .padding(14)
                        } else {
                            settingsRow(
                                icon: "target",
                                iconColor: JournalTheme.Colors.successGreen,
                                label: "Success criteria",
                                value: habit.successCriteria ?? "None"
                            ) {
                                Feedback.selection()
                                editedCriteria = CriteriaEditorView.parseCriteriaString(habit.successCriteria)
                                editingCriteria = true
                            }
                        }

                        Divider().padding(.leading, 48)

                        // Time of Day — expandable
                        settingsRow(
                            icon: "clock.fill",
                            iconColor: JournalTheme.Colors.navy,
                            label: "Time of day",
                            value: timeSlotSummary
                        ) {
                            Feedback.selection()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showTimeSlots.toggle()
                            }
                        }

                        if showTimeSlots {
                            TimeSlotPicker(selectedSlots: Binding(
                                get: { Set(habit.scheduleTimes) },
                                set: { newSlots in
                                    Feedback.selection()
                                    habit.scheduleTimes = Array(newSlots)
                                    store.updateHabit(habit)
                                }
                            ))
                            .padding(.horizontal, 14)
                            .padding(.bottom, 14)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // HealthKit Link (only show if HealthKit is available)
                        if healthKitManager.isAvailable {
                            Divider().padding(.leading, 48)

                            settingsRow(
                                icon: "heart.fill",
                                iconColor: .red,
                                label: "Apple Health",
                                value: healthKitLinkSummary
                            ) {
                                Feedback.selection()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showHealthKitEditor.toggle()
                                }
                            }

                            if showHealthKitEditor {
                                healthKitEditorContent
                                    .padding(.horizontal, 14)
                                    .padding(.bottom, 14)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.7))
                            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                    )
                }

                // MARK: - Actions
                VStack(spacing: 12) {
                    Button {
                        Feedback.archive()
                        if habit.isActive {
                            store.archiveHabit(habit)
                        } else {
                            store.unarchiveHabit(habit)
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: habit.isActive ? "archivebox" : "arrow.up.bin")
                            Text(habit.isActive ? "Archive habit" : "Unarchive habit")
                        }
                        .font(JournalTheme.Fonts.habitName())
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(JournalTheme.Colors.completedGray.opacity(0.5), lineWidth: 1.5)
                        )
                    }

                    Button {
                        Feedback.buttonPress()
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete habit")
                        }
                        .font(JournalTheme.Fonts.habitName())
                        .foregroundStyle(JournalTheme.Colors.negativeRedDark)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(JournalTheme.Colors.negativeRedDark.opacity(0.5), lineWidth: 1.5)
                        )
                    }
                }

                Spacer(minLength: 100)
            }
            .padding()
        }
        .linedPaperBackground()
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Habit?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { Feedback.buttonPress() }
            Button("Delete", role: .destructive) {
                Feedback.delete()
                store.deleteHabit(habit)
                dismiss()
            }
        } message: {
            Text("This will permanently delete '\(habit.name)' and all its history.")
        }
    }

    // MARK: - HealthKit Summary & Editor

    private var healthKitLinkSummary: String {
        if let metric = habit.healthKitMetric, let target = habit.healthKitTarget {
            let formattedTarget = HealthKitManager.shared.formatValue(target, for: metric)
            return "\(formattedTarget) \(metric.unit)"
        }
        return "Not linked"
    }

    @ViewBuilder
    private var healthKitEditorContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Metric picker
            Menu {
                Button("None") {
                    Feedback.selection()
                    habit.healthKitMetricType = nil
                    habit.healthKitTarget = nil
                    store.updateHabit(habit)
                }
                ForEach(HealthKitMetricType.allCases, id: \.self) { metric in
                    Button {
                        Feedback.selection()
                        habit.healthKitMetricType = metric.rawValue
                        if habit.healthKitTarget == nil {
                            habit.healthKitTarget = metric.defaultTarget
                        }
                        store.updateHabit(habit)
                    } label: {
                        Label(metric.displayName, systemImage: metric.icon)
                    }
                }
            } label: {
                HStack {
                    if let metric = habit.healthKitMetric {
                        Image(systemName: metric.icon)
                            .foregroundStyle(.red)
                        Text(metric.displayName)
                            .foregroundStyle(JournalTheme.Colors.inkBlack)
                    } else {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                        Text("Select a metric")
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.custom("PatrickHand-Regular", size: 12))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }
                .font(JournalTheme.Fonts.habitName())
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(JournalTheme.Colors.paperLight)
                )
            }

            // Target input (only if metric selected)
            if let metric = habit.healthKitMetric {
                HStack {
                    Text("Target:")
                        .font(.custom("PatrickHand-Regular", size: 14))
                        .foregroundStyle(JournalTheme.Colors.inkBlack)

                    TextField("", value: Binding(
                        get: { habit.healthKitTarget ?? metric.defaultTarget },
                        set: { newValue in
                            habit.healthKitTarget = newValue
                            store.updateHabit(habit)
                        }
                    ), format: .number)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                    .keyboardType(.decimalPad)
                    .frame(width: 70)
                    .multilineTextAlignment(.center)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                    )

                    Text(metric.unit)
                        .font(.custom("PatrickHand-Regular", size: 14))
                        .foregroundStyle(JournalTheme.Colors.completedGray)

                    Spacer()
                }

                // Auto-complete toggle
                HStack {
                    Text("Auto-complete")
                        .font(.custom("PatrickHand-Regular", size: 14))
                        .foregroundStyle(JournalTheme.Colors.inkBlack)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { habit.healthKitAutoComplete },
                        set: { newValue in
                            Feedback.selection()
                            habit.healthKitAutoComplete = newValue
                            store.updateHabit(habit)
                        }
                    ))
                    .labelsHidden()
                    .tint(.red)
                }

                // Current progress indicator
                if let currentValue = healthKitManager.currentValues[metric] {
                    let target = habit.healthKitTarget ?? metric.defaultTarget
                    let progress = min(currentValue / target, 1.0)
                    let isComplete = currentValue >= target

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Today's progress")
                                .font(.custom("PatrickHand-Regular", size: 12))
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                            Spacer()
                            Text("\(HealthKitManager.shared.formatValue(currentValue, for: metric))/\(HealthKitManager.shared.formatValue(target, for: metric)) \(metric.unit)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(isComplete ? JournalTheme.Colors.successGreen : JournalTheme.Colors.inkBlack)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(JournalTheme.Colors.lineLight)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isComplete ? JournalTheme.Colors.successGreen : .red.opacity(0.7))
                                    .frame(width: geo.size.width * progress)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Time Slot Summary

    private var timeSlotSummary: String {
        guard !habit.scheduleTimes.isEmpty else { return "Not set" }
        // Map raw values to shorter labels
        let shortLabels: [String: String] = [
            "After Wake": "Wake",
            "Morning": "Morning",
            "During the Day": "Daytime",
            "Evening": "Evening",
            "Before Bed": "Bed",
        ]
        let labels = habit.scheduleTimes.compactMap { shortLabels[$0] }
        if labels.isEmpty { return "Not set" }
        if labels.count <= 2 { return labels.joined(separator: ", ") }
        return "\(labels.count) slots"
    }

    // MARK: - Habit Icon

    @ViewBuilder
    private var habitIcon: some View {
        let iconSize: CGFloat = 72
        let emoji: String? = {
            for char in habit.name {
                if char.isEmoji { return String(char) }
            }
            return nil
        }()
        let initials: String = {
            let words = habit.name.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if words.count >= 2 {
                return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
            }
            return String(habit.name.prefix(2)).uppercased()
        }()
        let bgColor: Color = habit.tier == .mustDo ? JournalTheme.Colors.inkBlue : JournalTheme.Colors.goodDayGreenDark

        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(bgColor)
                .frame(width: iconSize, height: iconSize)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            if let emoji = emoji {
                Text(emoji)
                    .font(.custom("PatrickHand-Regular", size: 36))
            } else {
                Text(initials)
                    .font(.custom("PatrickHand-Regular", size: 24))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Settings Row

    private func settingsRow(icon: String, iconColor: Color, label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.custom("PatrickHand-Regular", size: 14))
                    .foregroundStyle(iconColor)
                    .frame(width: 24)

                Text(label)
                    .font(JournalTheme.Fonts.habitName())
                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                Spacer()

                Text(value)
                    .font(JournalTheme.Fonts.habitCriteria())
                    .foregroundStyle(JournalTheme.Colors.completedGray)

                Image(systemName: "chevron.right")
                    .font(.custom("PatrickHand-Regular", size: 12))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }
}

/// Stats cards section
struct HabitStatsSection: View {
    let habit: Habit
    let store: HabitStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STATISTICS")
                .font(JournalTheme.Fonts.sectionHeader())
                .foregroundStyle(JournalTheme.Colors.sectionHeader)
                .tracking(2)

            HStack(spacing: 16) {
                StatCard(
                    icon: "flame.fill",
                    iconColor: .orange,
                    value: "\(habit.currentStreak)",
                    label: "Current Streak"
                )

                StatCard(
                    icon: "trophy.fill",
                    iconColor: .yellow,
                    value: "\(habit.bestStreak)",
                    label: "Best Streak"
                )
            }

            HStack(spacing: 16) {
                StatCard(
                    icon: "chart.pie.fill",
                    iconColor: JournalTheme.Colors.inkBlue,
                    value: "\(Int(store.completionRate(for: habit) * 100))%",
                    label: "30-Day Rate"
                )

                let totalCompletions = (habit.dailyLogs ?? []).filter { $0.completed }.count
                StatCard(
                    icon: "checkmark.circle.fill",
                    iconColor: JournalTheme.Colors.goodDayGreenDark,
                    value: "\(totalCompletions)",
                    label: "Total Done"
                )
            }
        }
    }
}

/// Individual stat card
struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.custom("PatrickHand-Regular", size: 20))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.custom("PatrickHand-Regular", size: 24))
                .foregroundStyle(JournalTheme.Colors.inkBlack)

            Text(label)
                .font(JournalTheme.Fonts.habitCriteria())
                .foregroundStyle(JournalTheme.Colors.completedGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.7))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }
}

/// Recent activity section showing last 7 days
struct RecentActivitySection: View {
    let habit: Habit

    private var last7Days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LAST 7 DAYS")
                .font(JournalTheme.Fonts.sectionHeader())
                .foregroundStyle(JournalTheme.Colors.sectionHeader)
                .tracking(2)

            HStack(spacing: 8) {
                ForEach(last7Days, id: \.self) { date in
                    VStack(spacing: 4) {
                        Text(dayFormatter.string(from: date))
                            .font(.custom("PatrickHand-Regular", size: 10))
                            .foregroundStyle(JournalTheme.Colors.completedGray)

                        if habit.isCompleted(for: date) {
                            HandDrawnCheckmark(size: 24, color: JournalTheme.Colors.inkBlue)
                        } else {
                            Circle()
                                .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1.5)
                                .frame(width: 24, height: 24)
                        }
                    }
                    .frame(maxWidth: .infinity)
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
}

/// Section showing hobby logs with photos and notes
struct HobbyLogsSection: View {
    let habit: Habit
    let store: HabitStore

    @State private var selectedLogDate: HobbyLogSelection? = nil

    private var completedLogs: [DailyLog] {
        (habit.dailyLogs ?? [])
            .filter { $0.completed }
            .sorted { $0.date > $1.date }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOBBY LOGS")
                .font(JournalTheme.Fonts.sectionHeader())
                .foregroundStyle(JournalTheme.Colors.sectionHeader)
                .tracking(2)

            if completedLogs.isEmpty {
                Text("No completed entries yet")
                    .font(JournalTheme.Fonts.habitCriteria())
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.7))
                            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                    )
            } else {
                VStack(spacing: 8) {
                    ForEach(completedLogs.prefix(10)) { log in
                        HobbyLogRow(log: log, dateFormatter: dateFormatter)
                            .onTapGesture {
                                selectedLogDate = HobbyLogSelection(habit: habit, date: log.date)
                            }
                    }

                    if completedLogs.count > 10 {
                        Text("+ \(completedLogs.count - 10) more entries")
                            .font(JournalTheme.Fonts.habitCriteria())
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .sheet(item: $selectedLogDate) { selection in
            HobbyLogDetailSheet(
                habit: selection.habit,
                date: selection.date,
                onDismiss: {
                    selectedLogDate = nil
                },
                store: store
            )
        }
    }
}

/// A single row showing a hobby log entry
struct HobbyLogRow: View {
    let log: DailyLog
    let dateFormatter: DateFormatter

    @State private var loadedImage: UIImage? = nil

    private var hasContent: Bool { log.hasContent }

    var body: some View {
        HStack(spacing: 12) {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if !log.allPhotoPaths.isEmpty {
                RoundedRectangle(cornerRadius: 8)
                    .fill(JournalTheme.Colors.lineLight)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    )
            } else if hasContent {
                RoundedRectangle(cornerRadius: 8)
                    .fill(JournalTheme.Colors.lineLight)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "note.text")
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(JournalTheme.Colors.lineLight.opacity(0.5))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "plus.circle")
                            .foregroundStyle(JournalTheme.Colors.inkBlue.opacity(0.5))
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: log.date))
                    .font(.custom("PatrickHand-Regular", size: 14))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                if let note = log.note, !note.isEmpty {
                    Text(note)
                        .font(JournalTheme.Fonts.habitCriteria())
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                        .lineLimit(2)
                } else if !hasContent {
                    Text("Tap to add notes or photos")
                        .font(JournalTheme.Fonts.habitCriteria())
                        .foregroundStyle(JournalTheme.Colors.inkBlue.opacity(0.5))
                }
            }

            Spacer()

            Image(systemName: "pencil")
                .font(.custom("PatrickHand-Regular", size: 14))
                .foregroundStyle(JournalTheme.Colors.inkBlue)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.7))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
        .onAppear {
            loadPhoto()
        }
    }

    private func loadPhoto() {
        if let firstPath = log.allPhotoPaths.first {
            loadedImage = PhotoStorageService.shared.loadPhoto(from: firstPath)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Habit.self, HabitGroup.self, DailyLog.self, configurations: config)
    let store = HabitStore(modelContext: container.mainContext)

    let habit = Habit(
        name: "Drink water",
        habitDescription: "Stay hydrated throughout the day",
        tier: .mustDo,
        type: .positive,
        successCriteria: "3L",
        currentStreak: 7,
        bestStreak: 14
    )
    container.mainContext.insert(habit)

    return NavigationStack {
        HabitDetailView(store: store, habit: habit)
    }
}
