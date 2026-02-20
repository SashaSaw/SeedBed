import SwiftUI

/// Settings card for enabling Screen Time integration for habit tracking
struct ScreenTimeSettingsCard: View {
    @State private var screenTimeManager = ScreenTimeManager.shared
    @State private var isEnabled: Bool = false
    @State private var showingAuthError: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with toggle
            HStack {
                Image(systemName: "hourglass")
                    .font(.custom("PatrickHand-Regular", size: 18))
                    .foregroundStyle(JournalTheme.Colors.purple)

                Text("Screen Time")
                    .font(.custom("PatrickHand-Regular", size: 17))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                Spacer()

                Toggle("", isOn: $isEnabled)
                    .tint(JournalTheme.Colors.purple)
                    .labelsHidden()
                    .onChange(of: isEnabled) { _, newValue in
                        handleToggleChange(newValue)
                    }
            }

            if isEnabled && screenTimeManager.isAuthorized {
                // Enabled state
                Text("Link habits to app usage and auto-complete when you reach your target minutes.")
                    .font(.custom("PatrickHand-Regular", size: 13))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .fixedSize(horizontal: false, vertical: true)

                // How it works
                VStack(alignment: .leading, spacing: 8) {
                    Text("HOW IT WORKS")
                        .font(JournalTheme.Fonts.sectionHeader())
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                        .tracking(1.5)

                    VStack(alignment: .leading, spacing: 6) {
                        featureRow(icon: "app.badge", text: "Select an app when creating a habit")
                        featureRow(icon: "timer", text: "Set a target usage time (e.g. 30 min)")
                        featureRow(icon: "checkmark.circle", text: "Habit auto-completes when you hit the target")
                    }
                }
            } else if !isEnabled {
                // Disabled state
                Text("Enable to auto-complete habits based on how long you use specific apps.")
                    .font(.custom("PatrickHand-Regular", size: 13))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .fixedSize(horizontal: false, vertical: true)
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
        .onAppear {
            isEnabled = screenTimeManager.isAuthorized
        }
        .alert("Screen Time Access Required", isPresented: $showingAuthError) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                isEnabled = false
            }
        } message: {
            Text("Please enable Screen Time access for Sown in Settings to use this feature.")
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(JournalTheme.Colors.purple)
                .frame(width: 16)
            Text(text)
                .font(.custom("PatrickHand-Regular", size: 12))
                .foregroundStyle(JournalTheme.Colors.inkBlack)
        }
    }

    private func handleToggleChange(_ newValue: Bool) {
        Feedback.selection()

        if newValue {
            // Request authorization
            Task {
                await screenTimeManager.requestAuthorization()
                await MainActor.run {
                    if screenTimeManager.isAuthorized {
                        isEnabled = true
                    } else {
                        // Authorization denied
                        isEnabled = false
                        showingAuthError = true
                    }
                }
            }
        } else {
            // User disabled - just turn off (we can't revoke Screen Time permissions)
            isEnabled = false
        }
    }
}

#Preview {
    VStack {
        ScreenTimeSettingsCard()
            .padding()
    }
    .linedPaperBackground()
}
