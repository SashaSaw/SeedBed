import SwiftUI
import SwiftData
import FamilyControls
import ManagedSettings

/// How the don't-do habit failure will be tracked
enum DontDoMeasurementType: String, CaseIterable {
    case manual = "Manual"
    case screenTime = "Screen Time"
}

/// Simple don't-do habit creation with optional Screen Time tracking.
struct AddDontDoView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: HabitStore

    @State private var name = ""
    @State private var showConfirmation = false
    @State private var addedHabitName = ""

    // Screen Time state
    @State private var measurementType: DontDoMeasurementType = .manual
    @State private var screenTimeAppToken: ApplicationToken? = nil
    @State private var screenTimeTargetMinutes: Int = 15
    @State private var blockAfterLimit: Bool = false
    @State private var showingAppPicker = false
    @State private var familySelection = FamilyActivitySelection()
    @State private var screenTimeManager = ScreenTimeManager.shared

    @AppStorage("hasSeenIntegrationTutorial") private var hasSeenIntegrationTutorial = false
    @State private var showIntegrationTutorial = false

    @FocusState private var nameFieldFocused: Bool

    private var hasName: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Whether Screen Time selection is complete
    private var isScreenTimeConfigured: Bool {
        measurementType == .screenTime && screenTimeAppToken != nil
    }

    /// Whether form can be submitted
    private var canSubmit: Bool {
        hasName && (measurementType == .manual || isScreenTimeConfigured)
    }

    /// Quick-pick suggestions for common don't-do habits
    private let dontDoSuggestions: [(emoji: String, name: String)] = [
        ("📱", "Doomscroll"),
        ("🍬", "Eat junk food"),
        ("🚬", "Smoke"),
        ("🍺", "Drink alcohol"),
        ("💅", "Bite nails"),
        ("🛋️", "Skip workout"),
        ("☕", "Too much caffeine"),
        ("🛒", "Impulse buy"),
        ("😤", "Lose temper"),
    ]

    var body: some View {
        if showConfirmation {
            AddHabitConfirmationView(habitName: addedHabitName) { dismiss() }
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
                        measurementTypeSection
                    }

                    if hasName && measurementType == .screenTime {
                        screenTimeSection
                    }

                    if canSubmit {
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
        .onAppear {
            nameFieldFocused = true
            if !hasSeenIntegrationTutorial {
                showIntegrationTutorial = true
            }
        }
        .overlay {
            if showIntegrationTutorial {
                IntegrationTutorialOverlay {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        hasSeenIntegrationTutorial = true
                        showIntegrationTutorial = false
                    }
                }
                .transition(.opacity)
            }
        }
        .familyActivityPicker(isPresented: $showingAppPicker, selection: $familySelection)
        .onChange(of: familySelection) { _, newSelection in
            // Take only the first app token
            if let firstToken = newSelection.applicationTokens.first {
                withAnimation(.easeInOut(duration: 0.2)) {
                    screenTimeAppToken = firstToken
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("New don't-do")
                .font(JournalTheme.Fonts.title())
                .foregroundStyle(JournalTheme.Colors.negativeRedDark)

            Text("A habit you want to quit")
                .font(JournalTheme.Fonts.habitCriteria())
                .foregroundStyle(JournalTheme.Colors.completedGray)
                .italic()
        }
    }

    // MARK: - Name Input

    private var nameInputField: some View {
        TextField("What do you want to stop doing?", text: $name)
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
            .submitLabel(.next)
            .onSubmit { nameFieldFocused = false }
    }

    // MARK: - Quick Picks

    private var quickPicksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK PICKS")
                .font(JournalTheme.Fonts.sectionHeader())
                .foregroundStyle(JournalTheme.Colors.completedGray)
                .tracking(1.5)

            FlowLayout(spacing: 10) {
                ForEach(dontDoSuggestions, id: \.name) { suggestion in
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

    // MARK: - Measurement Type Section

    private var measurementTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW WILL YOU TRACK FAILURE?")
                .font(JournalTheme.Fonts.sectionHeader())
                .foregroundStyle(JournalTheme.Colors.completedGray)
                .tracking(1.5)

            HStack(spacing: 8) {
                ForEach(DontDoMeasurementType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            measurementType = type
                            if type == .manual {
                                // Clear Screen Time selection when switching to manual
                                screenTimeAppToken = nil
                                familySelection = FamilyActivitySelection()
                            }
                        }
                        Feedback.selection()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type == .manual ? "hand.tap" : "hourglass")
                                .font(.system(size: 12))
                            Text(type.rawValue)
                                .font(JournalTheme.Fonts.habitCriteria())
                        }
                        .foregroundStyle(measurementType == type ? .white : JournalTheme.Colors.inkBlack)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(measurementType == type ? JournalTheme.Colors.negativeRedDark : Color.white.opacity(0.85))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    measurementType == type
                                        ? Color.clear
                                        : JournalTheme.Colors.lineLight,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            if measurementType == .manual {
                Text("Tap to mark when you slip")
                    .font(JournalTheme.Fonts.habitCriteria())
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .italic()
            } else {
                Text("Auto-fail when you exceed time limit")
                    .font(JournalTheme.Fonts.habitCriteria())
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .italic()
            }
        }
    }

    // MARK: - Screen Time Section

    private var screenTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // App selection button
            Button {
                showingAppPicker = true
            } label: {
                HStack {
                    Image(systemName: "hourglass")
                        .foregroundStyle(screenTimeAppToken != nil ? JournalTheme.Colors.negativeRedDark : JournalTheme.Colors.completedGray)

                    if screenTimeAppToken != nil {
                        Text("App selected")
                            .foregroundStyle(JournalTheme.Colors.inkBlack)
                    } else {
                        Text("Select an app to limit")
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.custom("PatrickHand-Regular", size: 12))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }
                .font(JournalTheme.Fonts.habitName())
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            // Time limit (only if app selected)
            if screenTimeAppToken != nil {
                HStack {
                    Text("Time limit:")
                        .font(JournalTheme.Fonts.habitName())
                        .foregroundStyle(JournalTheme.Colors.inkBlack)

                    Spacer()

                    HStack(spacing: 0) {
                        Button {
                            if screenTimeTargetMinutes > 5 {
                                screenTimeTargetMinutes -= 5
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.custom("PatrickHand-Regular", size: 14))
                                .foregroundStyle(JournalTheme.Colors.negativeRedDark)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(JournalTheme.Colors.paperLight))
                        }
                        .buttonStyle(.plain)

                        Text("\(screenTimeTargetMinutes) min")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)
                            .frame(width: 70)

                        Button {
                            if screenTimeTargetMinutes < 120 {
                                screenTimeTargetMinutes += 5
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.custom("PatrickHand-Regular", size: 14))
                                .foregroundStyle(JournalTheme.Colors.negativeRedDark)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(JournalTheme.Colors.paperLight))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
                        )
                )

                // Block after limit toggle
                Toggle(isOn: $blockAfterLimit) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Block app after limit")
                            .font(JournalTheme.Fonts.habitName())
                            .foregroundStyle(JournalTheme.Colors.inkBlack)

                        Text("App will show a shield until tomorrow")
                            .font(JournalTheme.Fonts.habitCriteria())
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                            .italic()
                    }
                }
                .tint(JournalTheme.Colors.negativeRedDark)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
                        )
                )

                // Clear selection button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        screenTimeAppToken = nil
                        familySelection = FamilyActivitySelection()
                    }
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Remove app link")
                    }
                    .font(JournalTheme.Fonts.habitCriteria())
                    .foregroundStyle(JournalTheme.Colors.negativeRedDark)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button { addDontDo() } label: {
            Text("Add Don't-do")
                .font(.custom("PatrickHand-Regular", size: 17))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(JournalTheme.Colors.negativeRedDark)
                )
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Add Habit Logic

    private func addDontDo() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        // Strip emoji for display name
        var displayName = trimmedName
        if let first = displayName.first, first.isEmoji {
            displayName = String(displayName.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        addedHabitName = displayName.isEmpty ? trimmedName : displayName

        // Encode Screen Time token if selected
        let tokenData: Data? = if let token = screenTimeAppToken {
            try? PropertyListEncoder().encode(token)
        } else {
            nil
        }

        let habit = store.addHabit(
            name: trimmedName,
            tier: .mustDo,
            type: .negative,
            frequencyType: .daily,
            frequencyTarget: 1,
            isHobby: false,
            notificationsEnabled: false,
            enableNotesPhotos: false,
            screenTimeAppTokenData: tokenData,
            screenTimeTarget: measurementType == .screenTime ? screenTimeTargetMinutes : nil
        )

        // Set the blockOnExceed flag
        if measurementType == .screenTime {
            habit.screenTimeBlockOnExceed = blockAfterLimit
            store.updateHabit(habit)

            // Start monitoring for this habit
            store.startScreenTimeMonitoring()
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            showConfirmation = true
        }
    }
}

#Preview("Add Don't-Do") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Habit.self, HabitGroup.self, DailyLog.self, configurations: config)
    let store = HabitStore(modelContext: container.mainContext)

    return AddDontDoView(store: store)
}
