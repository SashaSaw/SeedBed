import SwiftUI
import FamilyControls

/// Card showing app selection count and FamilyActivityPicker trigger.
/// Selection changes are buffered — user must tap Save to apply.
struct BlockedAppsCard: View {
    @State private var screenTimeManager = ScreenTimeManager.shared
    @State private var blockSettings = BlockSettings.shared
    @State private var showingAppPicker = false

    // MARK: - Draft State

    @State private var draftSelection = FamilyActivitySelection()
    @State private var hasUnsavedChanges = false

    /// Whether the draft differs from the committed selection
    private var selectionChanged: Bool {
        draftSelection.applicationTokens != screenTimeManager.activitySelection.applicationTokens
        || draftSelection.categoryTokens != screenTimeManager.activitySelection.categoryTokens
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "apps.iphone")
                    .font(.custom("PatrickHand-Regular", size: 15))
                    .foregroundStyle(JournalTheme.Colors.coral)

                Text("Blocked Apps")
                    .font(.custom("PatrickHand-Regular", size: 15))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                if hasUnsavedChanges {
                    Text("(unsaved)")
                        .font(.custom("PatrickHand-Regular", size: 12))
                        .foregroundStyle(JournalTheme.Colors.amber)
                }
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

                        let appCount = draftSelection.applicationTokens.count
                        let catCount = draftSelection.categoryTokens.count
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
                selection: $draftSelection
            )
            .disabled(blockSettings.isEnabled && blockSettings.isCurrentlyActive)
            .opacity(blockSettings.isEnabled && blockSettings.isCurrentlyActive ? 0.6 : 1.0)
            .onChange(of: draftSelection) { _, _ in
                hasUnsavedChanges = selectionChanged
            }

            // App & category token icons (show draft)
            let appTokens = Array(draftSelection.applicationTokens)
            let catTokens = Array(draftSelection.categoryTokens)
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

            // Save / Discard buttons
            if hasUnsavedChanges {
                HStack(spacing: 12) {
                    Button {
                        Feedback.buttonPress()
                        draftSelection = screenTimeManager.activitySelection
                        hasUnsavedChanges = false
                    } label: {
                        Text("Discard")
                            .font(.custom("PatrickHand-Regular", size: 14))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(JournalTheme.Colors.lineMedium, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Feedback.buttonPress()
                        screenTimeManager.activitySelection = draftSelection
                        hasUnsavedChanges = false
                    } label: {
                        Text("Save Apps")
                            .font(.custom("PatrickHand-Regular", size: 14))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(JournalTheme.Colors.amber)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JournalTheme.Colors.paperLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(hasUnsavedChanges ? JournalTheme.Colors.amber.opacity(0.5) : JournalTheme.Colors.lineMedium, lineWidth: 1)
                )
        )
        .onAppear {
            draftSelection = screenTimeManager.activitySelection
        }
    }

    private func selectionSummary(apps: Int, categories: Int) -> String {
        var parts: [String] = []
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if categories > 0 { parts.append("\(categories) categor\(categories == 1 ? "y" : "ies")") }
        return parts.isEmpty ? "" : parts.joined(separator: ", ") + " selected"
    }
}
