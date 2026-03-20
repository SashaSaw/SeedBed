import SwiftUI
import FamilyControls
import ManagedSettings

/// Formats minutes into readable duration: "15 min" or "2h 30m"
func formatScreenTimeMinutes(_ minutes: Int) -> String {
    if minutes < 60 {
        return "\(minutes) min"
    }
    let h = minutes / 60
    let m = minutes % 60
    return m == 0 ? "\(h)h 0m" : "\(h)h \(m)m"
}

/// UI section for linking a habit to Screen Time apps with a usage target
struct ScreenTimeHabitSection: View {
    @Binding var appTokens: Set<ApplicationToken>
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
                            .foregroundStyle(!appTokens.isEmpty ? JournalTheme.Colors.purple : JournalTheme.Colors.completedGray)

                        if !appTokens.isEmpty {
                            FlowLayout(spacing: 4) {
                                ForEach(Array(appTokens), id: \.self) { token in
                                    Label(token)
                                        .labelStyle(.iconOnly)
                                        .scaleEffect(0.7)
                                        .frame(width: 28, height: 28)
                                }
                            }
                            Text("\(appTokens.count) app\(appTokens.count == 1 ? "" : "s") selected")
                                .foregroundStyle(JournalTheme.Colors.inkBlack)
                        } else {
                            Text("Select apps")
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

                // Target minutes (only if apps selected)
                if !appTokens.isEmpty {
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

                            Text(formatScreenTimeMinutes(targetMinutes))
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundStyle(JournalTheme.Colors.inkBlack)
                                .frame(width: 80)

                            Button {
                                if targetMinutes < 300 {
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

                // Clear selection button (if apps selected)
                if !appTokens.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appTokens = []
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
            let tokens = newSelection.applicationTokens
            if !tokens.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appTokens = tokens
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
            Text(formatScreenTimeMinutes(targetMinutes))
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
    @State private var appTokens: Set<ApplicationToken> = []
    @State private var targetMinutes: Int = 30

    var body: some View {
        ScrollView {
            VStack {
                ScreenTimeHabitSection(
                    appTokens: $appTokens,
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
