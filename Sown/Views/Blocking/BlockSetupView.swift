import SwiftUI
import FamilyControls

/// Configure-once screen for setting up app blocking via Screen Time APIs
struct BlockSetupView: View {
    @State private var blockSettings = BlockSettings.shared
    @State private var screenTimeManager = ScreenTimeManager.shared
    @State private var showingStartPicker = false
    @State private var showingEndPicker = false
    @State private var showingAppPicker = false
    @State private var showingEnableWarning = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Paper background
                LinedPaperBackground(lineSpacing: JournalTheme.Dimensions.lineSpacing)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        headerSection

                        // Authorization prompt (if not yet authorized)
                        if !screenTimeManager.isAuthorized {
                            authorizationCard
                        } else {
                            // Master toggle
                            masterToggle

                            // Block schedule card
                            scheduleCard
                                .disabled(blockSettings.isEnabled && blockSettings.isCurrentlyActive)
                                .opacity(blockSettings.isEnabled && blockSettings.isCurrentlyActive ? 0.6 : 1.0)

                            // App selection
                            appSelectionSection
                                .disabled(blockSettings.isEnabled && blockSettings.isCurrentlyActive)
                                .opacity(blockSettings.isEnabled && blockSettings.isCurrentlyActive ? 0.6 : 1.0)

                            // Info callout
                            infoCallout
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        HelpButton(section: .blocking)

                        Button("Done") {
                            Feedback.buttonPress()
                            dismiss()
                        }
                        .font(.custom("PatrickHand-Regular", size: 16))
                        .foregroundStyle(JournalTheme.Colors.inkBlue)
                    }
                }
            }
            .onChange(of: blockSettings.isEnabled) { _, isEnabled in
                if isEnabled {
                    screenTimeManager.enableBlocking()
                } else {
                    screenTimeManager.disableBlocking()
                }
            }
            .onChange(of: blockSettings.scheduleStartMinutes) { _, _ in
                screenTimeManager.updateBlocking()
            }
            .onChange(of: blockSettings.scheduleEndMinutes) { _, _ in
                screenTimeManager.updateBlocking()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Block Apps")
                .font(JournalTheme.Fonts.title())
                .foregroundStyle(JournalTheme.Colors.inkBlack)

            Text("Choose apps to block during focus hours")
                .font(JournalTheme.Fonts.habitCriteria())
                .foregroundStyle(JournalTheme.Colors.completedGray)
        }
    }

    // MARK: - Authorization Card

    private var authorizationCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.custom("PatrickHand-Regular", size: 36))
                .foregroundStyle(JournalTheme.Colors.amber)

            Text("Screen Time Access Required")
                .font(.custom("PatrickHand-Regular", size: 17))
                .foregroundStyle(JournalTheme.Colors.inkBlack)

            Text("Sown needs Screen Time permission to block distracting apps and show your habits instead.")
                .font(.custom("PatrickHand-Regular", size: 14))
                .foregroundStyle(JournalTheme.Colors.completedGray)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Feedback.buttonPress()
                Task {
                    await screenTimeManager.requestAuthorization()
                }
            } label: {
                Text("Grant Access")
                    .font(.custom("PatrickHand-Regular", size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(JournalTheme.Colors.amber)
                    )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JournalTheme.Colors.paperLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(JournalTheme.Colors.lineMedium, lineWidth: 1)
                )
        )
    }

    // MARK: - Master Toggle

    private var masterToggle: some View {
        let isLocked = blockSettings.isEnabled && blockSettings.isCurrentlyActive

        return VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Blocking")
                        .font(.custom("PatrickHand-Regular", size: 16))
                        .foregroundStyle(JournalTheme.Colors.inkBlack)

                    if isLocked, let remaining = blockSettings.timeRemainingString {
                        Text("Locked · \(remaining)")
                            .font(.custom("PatrickHand-Regular", size: 13))
                            .foregroundStyle(JournalTheme.Colors.negativeRedDark)
                    } else {
                        Text(blockSettings.isEnabled ? "Active · \(blockSettings.selectionSummary) selected" : "Disabled")
                            .font(.custom("PatrickHand-Regular", size: 13))
                            .foregroundStyle(blockSettings.isEnabled ? JournalTheme.Colors.successGreen : JournalTheme.Colors.completedGray)
                    }
                }

                Spacer()

                if isLocked {
                    // Show a locked icon instead of a toggle
                    Image(systemName: "lock.fill")
                        .font(.custom("PatrickHand-Regular", size: 16))
                        .foregroundStyle(JournalTheme.Colors.negativeRedDark)
                        .frame(width: 44, height: 30)
                } else {
                    Toggle("", isOn: Binding(
                        get: { blockSettings.isEnabled },
                        set: { newValue in
                            Feedback.selection()
                            if newValue {
                                // Show warning before enabling
                                showingEnableWarning = true
                            } else {
                                blockSettings.isEnabled = false
                            }
                        }
                    ))
                    .tint(JournalTheme.Colors.successGreen)
                    .labelsHidden()
                }
            }

            // Locked message
            if isLocked {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.custom("PatrickHand-Regular", size: 12))
                        .foregroundStyle(JournalTheme.Colors.negativeRedDark.opacity(0.6))
                    Text("App blocking cannot be turned off until the schedule ends.")
                        .font(.custom("PatrickHand-Regular", size: 12))
                        .foregroundStyle(JournalTheme.Colors.negativeRedDark.opacity(0.7))
                    Spacer()
                }
                .padding(.top, 12)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JournalTheme.Colors.paperLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isLocked ? JournalTheme.Colors.negativeRedDark.opacity(0.3) : JournalTheme.Colors.lineMedium, lineWidth: 1)
                )
        )
        .alert("Are you sure?", isPresented: $showingEnableWarning) {
            Button("Enable Blocking") {
                blockSettings.isEnabled = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Once app blocking is turned on, you will not be able to turn it off until the scheduled time is over. If you delete Sown while blocking is active, all your habit data will be permanently erased. Make sure your schedule and app selections are set correctly first.")
        }
    }

    // MARK: - Schedule Card

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            scheduleCardHeader
            scheduleTimeRange
            scheduleTimePickers
            scheduleDaySelector
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JournalTheme.Colors.paperLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(JournalTheme.Colors.lineMedium, lineWidth: 1)
                )
        )
    }

    private var scheduleCardHeader: some View {
        HStack {
            Image(systemName: "clock")
                .font(.custom("PatrickHand-Regular", size: 15))
                .foregroundStyle(JournalTheme.Colors.amber)

            Text("Block Schedule")
                .font(.custom("PatrickHand-Regular", size: 15))
                .foregroundStyle(JournalTheme.Colors.inkBlack)
        }
    }

    private var scheduleTimeRange: some View {
        HStack(spacing: 12) {
            timeButton(
                label: "From",
                time: blockSettings.startTimeString,
                isActive: showingStartPicker
            ) {
                showingStartPicker.toggle()
                showingEndPicker = false
            }

            Image(systemName: "arrow.right")
                .font(.custom("PatrickHand-Regular", size: 14))
                .foregroundStyle(JournalTheme.Colors.completedGray)

            timeButton(
                label: "Until",
                time: blockSettings.endTimeString,
                isActive: showingEndPicker
            ) {
                showingEndPicker.toggle()
                showingStartPicker = false
            }

            Spacer()
        }
    }

    private func timeButton(label: String, time: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        let fillColor: Color = isActive ? JournalTheme.Colors.amber.opacity(0.1) : JournalTheme.Colors.paperLight
        let borderColor: Color = isActive ? JournalTheme.Colors.amber : JournalTheme.Colors.lineMedium

        return Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.custom("PatrickHand-Regular", size: 11))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                Text(time)
                    .font(.custom("PatrickHand-Regular", size: 18))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(borderColor, lineWidth: 1)
                    )
            )
        }
    }

    @ViewBuilder
    private var scheduleTimePickers: some View {
        if showingStartPicker {
            DatePicker("Start time", selection: $blockSettings.startTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.light)
                .frame(maxHeight: 120)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }

        if showingEndPicker {
            DatePicker("End time", selection: $blockSettings.endTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.light)
                .frame(maxHeight: 120)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var scheduleDaySelector: some View {
        let days: [(String, Int)] = [("S", 1), ("M", 2), ("T", 3), ("W", 4), ("T", 5), ("F", 6), ("S", 7)]

        return HStack(spacing: 6) {
            ForEach(days, id: \.1) { label, day in
                let isActive = blockSettings.activeDays.contains(day)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if isActive {
                            blockSettings.activeDays.remove(day)
                        } else {
                            blockSettings.activeDays.insert(day)
                        }
                    }
                } label: {
                    Text(label)
                        .font(.custom("PatrickHand-Regular", size: 13))
                        .foregroundStyle(isActive ? .white : JournalTheme.Colors.completedGray)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(isActive ? JournalTheme.Colors.amber : JournalTheme.Colors.paper)
                                .overlay(
                                    Circle()
                                        .strokeBorder(isActive ? Color.clear : JournalTheme.Colors.lineMedium, lineWidth: 1)
                                )
                        )
                }
            }
        }
    }

    // MARK: - App Selection (FamilyActivityPicker)

    private var appSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APPS TO BLOCK")
                .font(JournalTheme.Fonts.sectionHeader())
                .foregroundStyle(JournalTheme.Colors.sectionHeader)
                .tracking(2)

            // Button to open the system FamilyActivityPicker
            Button {
                showingAppPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "apps.iphone")
                        .font(.custom("PatrickHand-Regular", size: 20))
                        .foregroundStyle(JournalTheme.Colors.coral)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose Apps & Categories")
                            .font(.custom("PatrickHand-Regular", size: 15))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)

                        let appCount = screenTimeManager.activitySelection.applicationTokens.count
                        let catCount = screenTimeManager.activitySelection.categoryTokens.count
                        if appCount > 0 || catCount > 0 {
                            Text(selectionSummary(apps: appCount, categories: catCount))
                                .font(.custom("PatrickHand-Regular", size: 12))
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                        } else {
                            Text("No apps selected yet")
                                .font(.custom("PatrickHand-Regular", size: 12))
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.custom("PatrickHand-Regular", size: 13))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(JournalTheme.Colors.paperLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(JournalTheme.Colors.lineMedium, lineWidth: 1)
                        )
                )
            }
            .familyActivityPicker(
                isPresented: $showingAppPicker,
                selection: $screenTimeManager.activitySelection
            )
        }
    }

    private func selectionSummary(apps: Int, categories: Int) -> String {
        var parts: [String] = []
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if categories > 0 { parts.append("\(categories) categor\(categories == 1 ? "y" : "ies")") }
        return parts.joined(separator: ", ") + " selected"
    }

    // MARK: - Info Callout

    private var infoCallout: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("💡")
                .font(.custom("PatrickHand-Regular", size: 20))

            Text("When you try to open a blocked app, you'll see a shield. Open Sown to see your habits for today instead.")
                .font(JournalTheme.Fonts.habitCriteria())
                .foregroundStyle(JournalTheme.Colors.sectionHeader)
                .fixedSize(horizontal: false, vertical: true)
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
    }
}

#Preview {
    BlockSetupView()
}
