import SwiftUI
import Combine

/// Hero status card showing blocking state, time remaining, and master toggle
struct BlockStatusCard: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var blockSettings = BlockSettings.shared
    @State private var screenTimeManager = ScreenTimeManager.shared
    @State private var showingEnableWarning = false
    @State private var refreshTick = false

    var body: some View {
        let _ = refreshTick
        let isLocked = blockSettings.isEnabled && blockSettings.isCurrentlyActive

        VStack(spacing: 16) {
            // Authorization prompt
            if !screenTimeManager.isAuthorized {
                authorizationPrompt
            } else {
                // Icon + status
                HStack(spacing: 16) {
                    Image(systemName: blockSettings.isEnabled ? "lock.shield.fill" : "lock.shield")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            blockSettings.isCurrentlyActive
                                ? JournalTheme.Colors.negativeRedDark
                                : blockSettings.isEnabled
                                    ? JournalTheme.Colors.successGreen
                                    : JournalTheme.Colors.completedGray
                        )
                        .symbolEffect(.pulse, options: .repeating, isActive: blockSettings.isCurrentlyActive)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            blockSettings.isCurrentlyActive
                                ? "Blocking Active"
                                : blockSettings.isEnabled
                                    ? "Blocking Enabled"
                                    : "Blocking Off"
                        )
                            .font(.custom("PatrickHand-Regular", size: 20))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)

                        if blockSettings.selectedCount > 0 {
                            Text(blockSettings.selectionSummary)
                                .font(.custom("PatrickHand-Regular", size: 13))
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                        } else {
                            Text("No apps selected")
                                .font(.custom("PatrickHand-Regular", size: 13))
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                        }

                        if let remaining = blockSettings.timeRemainingString {
                            Text(remaining)
                                .font(.custom("PatrickHand-Regular", size: 14))
                                .foregroundStyle(JournalTheme.Colors.negativeRedDark)
                        } else if let nextBlock = blockSettings.nextBlockTimeString {
                            Text(nextBlock)
                                .font(.custom("PatrickHand-Regular", size: 13))
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                        }
                    }

                    Spacer()

                    // Toggle or lock icon
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(JournalTheme.Colors.negativeRedDark)
                            .frame(width: 44, height: 30)
                    } else {
                        Toggle("", isOn: Binding(
                            get: { blockSettings.isEnabled },
                            set: { newValue in
                                Feedback.selection()
                                if newValue {
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
                            .font(.system(size: 12))
                            .foregroundStyle(JournalTheme.Colors.negativeRedDark.opacity(0.6))
                        Text("Blocking cannot be turned off until the schedule ends.")
                            .font(.custom("PatrickHand-Regular", size: 12))
                            .foregroundStyle(JournalTheme.Colors.negativeRedDark.opacity(0.7))
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JournalTheme.Colors.paperLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isLocked ? JournalTheme.Colors.negativeRedDark.opacity(0.3) : JournalTheme.Colors.lineMedium,
                            lineWidth: 1
                        )
                )
        )
        .alert("Are you sure?", isPresented: $showingEnableWarning) {
            Button("Enable Blocking") {
                blockSettings.isEnabled = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Once app blocking is turned on, you will not be able to turn it off until the scheduled time is over. Make sure your schedule and app selections are set correctly first.")
        }
        .onChange(of: blockSettings.isEnabled) { _, isEnabled in
            if isEnabled {
                screenTimeManager.enableBlocking()
            } else {
                screenTimeManager.disableBlocking()
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            refreshTick.toggle()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { refreshTick.toggle() }
        }
    }

    // MARK: - Authorization Prompt

    private var authorizationPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 36))
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
    }
}
