import SwiftUI
import FamilyControls
import ManagedSettings

/// UI section for linking a habit to a Screen Time app with a usage target
struct ScreenTimeHabitSection: View {
    @Binding var appToken: ApplicationToken?
    @Binding var targetMinutes: Int
    var onTokenSelected: () -> Void = {}

    @State private var showingAppPicker = false
    @State private var selection = FamilyActivitySelection()
    @State private var screenTimeManager = ScreenTimeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LINK TO APP USAGE")
                .font(JournalTheme.Fonts.sectionHeader())
                .foregroundStyle(JournalTheme.Colors.completedGray)
                .tracking(1.5)

            Text("Auto-complete this habit when you use an app for a set time")
                .font(JournalTheme.Fonts.habitCriteria())
                .foregroundStyle(JournalTheme.Colors.completedGray)
                .italic()

            VStack(spacing: 12) {
                // App selection button
                Button {
                    showingAppPicker = true
                } label: {
                    HStack {
                        Image(systemName: "hourglass")
                            .foregroundStyle(appToken != nil ? JournalTheme.Colors.purple : JournalTheme.Colors.completedGray)

                        if appToken != nil {
                            Text("App selected")
                                .foregroundStyle(JournalTheme.Colors.inkBlack)
                        } else {
                            Text("Select an app")
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

                // Target minutes (only if app selected)
                if appToken != nil {
                    HStack {
                        Text("Target:")
                            .font(JournalTheme.Fonts.habitName())
                            .foregroundStyle(JournalTheme.Colors.inkBlack)

                        Spacer()

                        HStack(spacing: 0) {
                            Button {
                                if targetMinutes > 5 {
                                    targetMinutes -= 5
                                }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.custom("PatrickHand-Regular", size: 14))
                                    .foregroundStyle(JournalTheme.Colors.purple)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(JournalTheme.Colors.paperLight))
                            }
                            .buttonStyle(.plain)

                            Text("\(targetMinutes) min")
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundStyle(JournalTheme.Colors.inkBlack)
                                .frame(width: 70)

                            Button {
                                if targetMinutes < 120 {
                                    targetMinutes += 5
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.custom("PatrickHand-Regular", size: 14))
                                    .foregroundStyle(JournalTheme.Colors.purple)
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
                }

                // Clear selection button (if app selected)
                if appToken != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appToken = nil
                            selection = FamilyActivitySelection()
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
        .familyActivityPicker(isPresented: $showingAppPicker, selection: $selection)
        .onChange(of: selection) { _, newSelection in
            // Take only the first app token (single app selection)
            if let firstToken = newSelection.applicationTokens.first {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appToken = firstToken
                }
                onTokenSelected()
            }
        }
    }
}

/// Progress badge showing Screen Time usage for a habit
struct ScreenTimeProgressBadge: View {
    let targetMinutes: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "hourglass")
                .font(.system(size: 9))
            Text("\(targetMinutes) min")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(JournalTheme.Colors.purple)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(JournalTheme.Colors.purple.opacity(0.12))
        )
    }
}

#Preview("Screen Time Section") {
    ScreenTimeHabitSectionPreview()
}

/// Preview wrapper for ScreenTimeHabitSection
private struct ScreenTimeHabitSectionPreview: View {
    @State private var appToken: ApplicationToken? = nil
    @State private var targetMinutes: Int = 30

    var body: some View {
        ScrollView {
            VStack {
                ScreenTimeHabitSection(
                    appToken: $appToken,
                    targetMinutes: $targetMinutes
                )
                .padding()
            }
        }
        .linedPaperBackground()
    }
}

#Preview("Progress Badge") {
    HStack {
        ScreenTimeProgressBadge(targetMinutes: 30)
        ScreenTimeProgressBadge(targetMinutes: 15)
    }
    .padding()
    .linedPaperBackground()
}
