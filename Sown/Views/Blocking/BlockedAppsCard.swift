import SwiftUI
import FamilyControls

/// Card showing app selection count and FamilyActivityPicker trigger
struct BlockedAppsCard: View {
    @State private var screenTimeManager = ScreenTimeManager.shared
    @State private var blockSettings = BlockSettings.shared
    @State private var showingAppPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "apps.iphone")
                    .font(.custom("PatrickHand-Regular", size: 15))
                    .foregroundStyle(JournalTheme.Colors.coral)

                Text("Blocked Apps")
                    .font(.custom("PatrickHand-Regular", size: 15))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
            }

            Button {
                Feedback.buttonPress()
                showingAppPicker = true
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose Apps & Categories")
                            .font(.custom("PatrickHand-Regular", size: 15))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)

                        let appCount = screenTimeManager.activitySelection.applicationTokens.count
                        let catCount = screenTimeManager.activitySelection.categoryTokens.count
                        if appCount > 0 || catCount > 0 {
                            Text(blockSettings.selectionSummary + " selected")
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
                        .font(.system(size: 13))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(JournalTheme.Colors.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(JournalTheme.Colors.lineMedium, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .familyActivityPicker(
                isPresented: $showingAppPicker,
                selection: $screenTimeManager.activitySelection
            )
            .disabled(blockSettings.isEnabled && blockSettings.isCurrentlyActive)
            .opacity(blockSettings.isEnabled && blockSettings.isCurrentlyActive ? 0.6 : 1.0)

            // App & category token icons
            let appTokens = Array(screenTimeManager.activitySelection.applicationTokens)
            let catTokens = Array(screenTimeManager.activitySelection.categoryTokens)
            if !appTokens.isEmpty || !catTokens.isEmpty {
                LazyVGrid(columns: Array(repeating: SwiftUI.GridItem(.fixed(36), spacing: 8), count: 8), spacing: 8) {
                    ForEach(appTokens, id: \.self) { token in
                        Label(token)
                            .labelStyle(.iconOnly)
                            .scaleEffect(0.8)
                            .frame(width: 36, height: 36)
                    }
                    ForEach(catTokens, id: \.self) { token in
                        Label(token)
                            .labelStyle(.iconOnly)
                            .scaleEffect(0.8)
                            .frame(width: 36, height: 36)
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
                        .strokeBorder(JournalTheme.Colors.lineMedium, lineWidth: 1)
                )
        )
    }
}
