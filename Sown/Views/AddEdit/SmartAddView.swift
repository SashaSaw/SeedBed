import SwiftUI
import SwiftData

/// AI-powered natural language habit creation
struct SmartAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: HabitStore

    enum Phase {
        case apiKey
        case input
        case loading
        case review
    }

    @State private var phase: Phase = .input
    @State private var inputText = ""
    @State private var parsedData: ParsedHabitData?
    @State private var errorMessage: String?
    @State private var errorCanRetry = false
    @State private var errorShowsSettings = false

    // Review phase editable fields
    @State private var editName = ""
    @State private var editTier: HabitTier = .mustDo
    @State private var editType: HabitType = .positive
    @State private var editFrequencyType: FrequencyType = .daily
    @State private var editFrequencyTarget: Int = 1
    @State private var editSuccessCriteria = ""
    @State private var editHabitPrompt = ""
    @State private var editScheduleTimes: Set<String> = []
    @State private var editIsHobby = false
    @State private var editOptions: [String] = []

    // Confirmation
    @State private var showConfirmation = false
    @State private var addedHabitName = ""

    // API key input
    @State private var apiKeyInput = ""

    @FocusState private var inputFocused: Bool

    private let apiService = ClaudeAPIService.shared

    var body: some View {
        if showConfirmation {
            AddHabitConfirmationView(habitName: addedHabitName) { dismiss() }
        } else {
            mainContent
        }
    }

    private var mainContent: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    switch phase {
                    case .apiKey:
                        apiKeySection
                    case .input:
                        inputSection
                    case .loading:
                        loadingSection
                    case .review:
                        reviewSection
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
            if APIKeyStorage.load() == nil {
                phase = .apiKey
            } else {
                phase = .input
                inputFocused = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.custom("PatrickHand-Regular", size: 26))
                    .foregroundStyle(JournalTheme.Colors.teal)

                Text("Smart Add")
                    .font(JournalTheme.Fonts.title())
                    .foregroundStyle(JournalTheme.Colors.teal)
            }

            Text("Describe a habit and AI fills in the details")
                .font(JournalTheme.Fonts.habitCriteria())
                .foregroundStyle(JournalTheme.Colors.completedGray)
                .italic()
        }
    }

    // MARK: - Phase 0: API Key

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SETUP")
                .font(JournalTheme.Fonts.sectionHeader())
                .foregroundStyle(JournalTheme.Colors.completedGray)
                .tracking(1.5)

            Text("Enter your Anthropic API key to get started")
                .font(JournalTheme.Fonts.habitName())
                .foregroundStyle(JournalTheme.Colors.inkBlack)

            SecureField("sk-ant-...", text: $apiKeyInput)
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(JournalTheme.Colors.inkBlack)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
                        )
                )
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button {
                Feedback.buttonPress()
                let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                if APIKeyStorage.save(apiKey: trimmed) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        phase = .input
                        inputFocused = true
                    }
                }
            } label: {
                Text("Save Key")
                    .font(.custom("PatrickHand-Regular", size: 17))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(JournalTheme.Colors.navy)
                    )
            }
            .buttonStyle(.plain)
            .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

            Text("Get a key at console.anthropic.com")
                .font(.custom("PatrickHand-Regular", size: 13))
                .foregroundStyle(JournalTheme.Colors.completedGray)
        }
    }

    // MARK: - Phase 1: Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Error banner
            if let error = errorMessage {
                errorBanner(message: error)
            }

            // Microphone hint button + text field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("DESCRIBE YOUR HABIT")
                        .font(JournalTheme.Fonts.sectionHeader())
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                        .tracking(1.5)

                    Spacer()

                    Button {
                        Feedback.selection()
                        inputFocused = true
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(JournalTheme.Colors.teal)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(JournalTheme.Colors.teal.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }

                TextField("", text: $inputText, axis: .vertical)
                    .font(JournalTheme.Fonts.habitName())
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                    .lineLimit(3...6)
                    .focused($inputFocused)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
                            )
                    )
                    .overlay(alignment: .topLeading) {
                        if inputText.isEmpty {
                            Text("Describe a habit in your own words...")
                                .font(JournalTheme.Fonts.habitName())
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                                .padding(16)
                                .allowsHitTesting(false)
                        }
                    }
            }

            // Example prompts
            VStack(alignment: .leading, spacing: 6) {
                Text("Try something like:")
                    .font(.custom("PatrickHand-Regular", size: 14))
                    .foregroundStyle(JournalTheme.Colors.completedGray)

                ForEach(examplePrompts, id: \.self) { prompt in
                    Button {
                        inputText = prompt
                        Feedback.selection()
                    } label: {
                        Text("\"" + prompt + "\"")
                            .font(.custom("PatrickHand-Regular", size: 14))
                            .foregroundStyle(JournalTheme.Colors.inkBlue)
                            .italic()
                    }
                    .buttonStyle(.plain)
                }
            }

            // Generate button
            Button {
                Feedback.buttonPress()
                generateHabit()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 15))
                    Text("Generate")
                        .font(.custom("PatrickHand-Regular", size: 17))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(JournalTheme.Colors.navy)
                )
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
    }

    private var examplePrompts: [String] {
        [
            "I want to run 3 times a week",
            "I need to stop doomscrolling",
            "Read before bed every night"
        ]
    }

    // MARK: - Phase 2: Loading

    private var loadingSection: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)

            ProgressView()
                .scaleEffect(1.2)
                .tint(JournalTheme.Colors.teal)

            Text("Thinking...")
                .font(JournalTheme.Fonts.habitName())
                .foregroundStyle(JournalTheme.Colors.completedGray)

            Button {
                Feedback.buttonPress()
                withAnimation(.easeInOut(duration: 0.25)) {
                    phase = .input
                }
            } label: {
                Text("Cancel")
                    .font(.custom("PatrickHand-Regular", size: 15))
                    .foregroundStyle(JournalTheme.Colors.inkBlue)
                    .underline()
            }
            .buttonStyle(.plain)

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Phase 3: Review

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("REVIEW & EDIT")
                .font(JournalTheme.Fonts.sectionHeader())
                .foregroundStyle(JournalTheme.Colors.completedGray)
                .tracking(1.5)

            // Name
            VStack(alignment: .leading, spacing: 6) {
                Text("NAME")
                    .font(.custom("PatrickHand-Regular", size: 12))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .tracking(1)

                TextField("Habit name", text: $editName)
                    .font(JournalTheme.Fonts.habitName())
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
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

            // Type & Tier pills
            HStack(spacing: 12) {
                // Type pill
                VStack(alignment: .leading, spacing: 6) {
                    Text("TYPE")
                        .font(.custom("PatrickHand-Regular", size: 12))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                        .tracking(1)

                    HStack(spacing: 8) {
                        pillButton(label: "Build", selected: editType == .positive) {
                            editType = .positive
                        }
                        pillButton(label: "Quit", selected: editType == .negative) {
                            editType = .negative
                        }
                    }
                }

                Spacer()

                // Tier pill
                VStack(alignment: .leading, spacing: 6) {
                    Text("PRIORITY")
                        .font(.custom("PatrickHand-Regular", size: 12))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                        .tracking(1)

                    HStack(spacing: 8) {
                        pillButton(label: "Must Do", selected: editTier == .mustDo) {
                            editTier = .mustDo
                        }
                        pillButton(label: "Nice To Do", selected: editTier == .niceToDo) {
                            editTier = .niceToDo
                        }
                    }
                }
            }

            // Frequency
            VStack(alignment: .leading, spacing: 6) {
                Text("FREQUENCY")
                    .font(.custom("PatrickHand-Regular", size: 12))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .tracking(1)

                FlowLayout(spacing: 8) {
                    ForEach(FrequencyType.allCases, id: \.self) { freq in
                        pillButton(label: freq.displayName, selected: editFrequencyType == freq) {
                            editFrequencyType = freq
                        }
                    }
                }

                if editFrequencyType == .weekly || editFrequencyType == .monthly {
                    HStack(spacing: 12) {
                        Text(editFrequencyType == .weekly ? "Times per week:" : "Times per month:")
                            .font(JournalTheme.Fonts.habitCriteria())
                            .foregroundStyle(JournalTheme.Colors.inkBlack)

                        Button {
                            if editFrequencyTarget > 1 { editFrequencyTarget -= 1 }
                            Feedback.selection()
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(JournalTheme.Colors.navy)
                        }
                        .buttonStyle(.plain)

                        Text("\(editFrequencyTarget)")
                            .font(.custom("PatrickHand-Regular", size: 18))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)
                            .frame(width: 30)
                            .multilineTextAlignment(.center)

                        Button {
                            let max = editFrequencyType == .weekly ? 7 : 31
                            if editFrequencyTarget < max { editFrequencyTarget += 1 }
                            Feedback.selection()
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(JournalTheme.Colors.navy)
                        }
                        .buttonStyle(.plain)
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
                }
            }

            // Success criteria
            if !editSuccessCriteria.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SUCCESS CRITERIA")
                        .font(.custom("PatrickHand-Regular", size: 12))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                        .tracking(1)

                    TextField("e.g. 10 minutes, 5km", text: $editSuccessCriteria)
                        .font(JournalTheme.Fonts.habitName())
                        .foregroundStyle(JournalTheme.Colors.inkBlack)
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
            }

            // Habit prompt
            VStack(alignment: .leading, spacing: 6) {
                Text("FIRST STEP PROMPT")
                    .font(.custom("PatrickHand-Regular", size: 12))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .tracking(1)

                TextField("Tiny action to get started", text: $editHabitPrompt)
                    .font(JournalTheme.Fonts.habitName())
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
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

            // Schedule times
            VStack(alignment: .leading, spacing: 6) {
                Text("WHEN")
                    .font(.custom("PatrickHand-Regular", size: 12))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .tracking(1)

                TimeSlotPicker(selectedSlots: $editScheduleTimes)
            }

            // Add Habit button
            Button { addHabit() } label: {
                Text("Add Habit")
                    .font(.custom("PatrickHand-Regular", size: 17))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(JournalTheme.Colors.navy)
                    )
            }
            .buttonStyle(.plain)
            .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(editName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

            // Try again link
            Button {
                Feedback.buttonPress()
                withAnimation(.easeInOut(duration: 0.25)) {
                    phase = .input
                    errorMessage = nil
                }
            } label: {
                Text("Try again with different words")
                    .font(JournalTheme.Fonts.habitCriteria())
                    .foregroundStyle(JournalTheme.Colors.inkBlue)
                    .underline()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))

            Text(message)
                .font(.custom("PatrickHand-Regular", size: 15))

            Spacer()

            if errorCanRetry {
                Button {
                    Feedback.buttonPress()
                    errorMessage = nil
                    generateHabit()
                } label: {
                    Text("Retry")
                        .font(.custom("PatrickHand-Regular", size: 14))
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(JournalTheme.Colors.coral)
        )
    }

    // MARK: - Pill Button

    private func pillButton(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Feedback.selection()
            action()
        } label: {
            Text(label)
                .font(.custom("PatrickHand-Regular", size: 15))
                .foregroundStyle(selected ? .white : JournalTheme.Colors.inkBlack)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selected ? JournalTheme.Colors.navy : Color.clear)
                        .overlay(
                            Capsule()
                                .strokeBorder(selected ? Color.clear : JournalTheme.Colors.lineLight, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func generateHabit() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.25)) {
            phase = .loading
            errorMessage = nil
        }

        Task {
            do {
                let result = try await apiService.parseHabit(input: text)
                await MainActor.run {
                    populateReviewFields(from: result)
                    withAnimation(.easeInOut(duration: 0.25)) {
                        phase = .review
                    }
                }
            } catch let error as ClaudeAPIError {
                await MainActor.run {
                    errorMessage = error.errorDescription
                    errorCanRetry = error.canRetry
                    errorShowsSettings = error.shouldShowSettings
                    withAnimation(.easeInOut(duration: 0.25)) {
                        phase = .input
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Something went wrong"
                    errorCanRetry = true
                    withAnimation(.easeInOut(duration: 0.25)) {
                        phase = .input
                    }
                }
            }
        }
    }

    private func populateReviewFields(from data: ParsedHabitData) {
        parsedData = data
        editName = data.name
        editTier = HabitTier(rawValue: data.tier) ?? .mustDo
        editType = HabitType(rawValue: data.type) ?? .positive
        editFrequencyType = FrequencyType(rawValue: data.frequencyType) ?? .daily
        editFrequencyTarget = data.frequencyTarget
        editSuccessCriteria = data.successCriteria ?? ""
        editHabitPrompt = data.habitPrompt
        editIsHobby = data.isHobby
        editOptions = data.options ?? []

        if let times = data.scheduleTimes {
            editScheduleTimes = Set(times)
        } else {
            editScheduleTimes = []
        }
    }

    private func addHabit() {
        let trimmedName = editName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        addedHabitName = trimmedName

        let _ = store.addHabit(
            name: trimmedName,
            tier: editTier,
            type: editType,
            frequencyType: editFrequencyType,
            frequencyTarget: editFrequencyTarget,
            successCriteria: editSuccessCriteria.isEmpty ? nil : editSuccessCriteria,
            isHobby: editIsHobby,
            options: editOptions,
            habitPrompt: editHabitPrompt.trimmingCharacters(in: .whitespaces),
            scheduleTimes: Array(editScheduleTimes)
        )

        Feedback.success()

        withAnimation(.easeInOut(duration: 0.3)) {
            showConfirmation = true
        }
    }
}

#Preview("Smart Add") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Habit.self, HabitGroup.self, DailyLog.self, configurations: config)
    let store = HabitStore(modelContext: container.mainContext)

    return SmartAddView(store: store)
}
