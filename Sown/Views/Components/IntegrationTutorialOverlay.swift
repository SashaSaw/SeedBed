import SwiftUI
import HealthKit

/// First-time overlay shown in Add flows to let users enable Health App and Screen Time integrations.
struct IntegrationTutorialOverlay: View {
    let onDismiss: () -> Void

    @State private var healthKitManager = HealthKitManager.shared
    @State private var screenTimeManager = ScreenTimeManager.shared
    @State private var healthKitRequesting = false
    @State private var screenTimeRequesting = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.white.opacity(0.96)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Title
                Text("Supercharge your habits")
                    .font(.custom("PatrickHand-Regular", size: 26))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                    .multilineTextAlignment(.center)

                Text("Connect integrations to auto-complete habits")
                    .font(.custom("PatrickHand-Regular", size: 15))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
                    .frame(height: 8)

                // Health App card
                healthCard

                // Screen Time card
                screenTimeCard

                Spacer()

                // Got it button
                Button {
                    Feedback.buttonPress()
                    onDismiss()
                } label: {
                    Text("Got it")
                        .font(.custom("PatrickHand-Regular", size: 18))
                        .foregroundStyle(.white)
                        .frame(width: 160)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(JournalTheme.Colors.inkBlue)
                        )
                }
                .buttonStyle(.plain)

                Text("You can change these anytime in Settings")
                    .font(.custom("PatrickHand-Regular", size: 12))
                    .foregroundStyle(JournalTheme.Colors.completedGray)

                Spacer()
                    .frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Health App Card

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.red)

                Text("Apple Health")
                    .font(.custom("PatrickHand-Regular", size: 18))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
            }

            Text("Auto-complete habits when you hit step goals, exercise minutes, and more")
                .font(.custom("PatrickHand-Regular", size: 14))
                .foregroundStyle(JournalTheme.Colors.completedGray)

            if !healthKitManager.isAvailable {
                // Not available (e.g. iPad)
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                    Text("Not available on this device")
                        .font(.custom("PatrickHand-Regular", size: 14))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }
            } else if healthKitManager.isAuthorized {
                // Already enabled
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                    Text("Enabled")
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(.green)
                }
                .transition(.opacity)
            } else {
                // Enable button
                Button {
                    healthKitRequesting = true
                    Task {
                        let _ = await healthKitManager.requestAuthorization()
                        await MainActor.run {
                            healthKitRequesting = false
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if healthKitRequesting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.red)
                        }
                        Text("Enable")
                            .font(.custom("PatrickHand-Regular", size: 15))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red.opacity(0.85))
                    )
                }
                .buttonStyle(.plain)
                .disabled(healthKitRequesting)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(JournalTheme.Colors.paperLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Screen Time Card

    private var screenTimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "hourglass")
                    .font(.system(size: 18))
                    .foregroundStyle(.purple)

                Text("Screen Time")
                    .font(.custom("PatrickHand-Regular", size: 18))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
            }

            Text("Track app usage and auto-complete habits based on time spent")
                .font(.custom("PatrickHand-Regular", size: 14))
                .foregroundStyle(JournalTheme.Colors.completedGray)

            if screenTimeManager.isAuthorized {
                // Already enabled
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                    Text("Enabled")
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(.green)
                }
                .transition(.opacity)
            } else {
                // Enable button
                Button {
                    screenTimeRequesting = true
                    Task {
                        await screenTimeManager.requestAuthorization()
                        await MainActor.run {
                            screenTimeRequesting = false
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if screenTimeRequesting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.purple)
                        }
                        Text("Enable")
                            .font(.custom("PatrickHand-Regular", size: 15))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.purple.opacity(0.85))
                    )
                }
                .buttonStyle(.plain)
                .disabled(screenTimeRequesting)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(JournalTheme.Colors.paperLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}
