import SwiftUI

/// Banner shown on the Block tab when apps are failure-blocked (Don't-Do limit exceeded).
/// Reads habit info from shared App Group defaults written by the DeviceActivityMonitor extension.
struct FailureBlockBanner: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var entries: [Entry] = []

    private static let appGroupID = "group.com.incept5.SeedBed"

    private struct Entry: Identifiable {
        let id = UUID()
        let habitName: String
        let targetMinutes: Int
    }

    var body: some View {
        Group {
            if !entries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(JournalTheme.Colors.negativeRedDark)

                        Text("Apps Blocked Until Midnight")
                            .font(.custom("PatrickHand-Regular", size: 15))
                            .foregroundStyle(JournalTheme.Colors.negativeRedDark)
                    }

                    ForEach(entries) { entry in
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(JournalTheme.Colors.negativeRedDark.opacity(0.7))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("'\(entry.habitName)' — habit slipped")
                                    .font(.custom("PatrickHand-Regular", size: 14))
                                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                                Text("You exceeded the \(entry.targetMinutes)-minute limit")
                                    .font(.custom("PatrickHand-Regular", size: 12))
                                    .foregroundStyle(JournalTheme.Colors.completedGray)
                            }

                            Spacer()
                        }
                    }

                    Text("These apps will be unblocked at midnight.")
                        .font(.custom("PatrickHand-Regular", size: 12))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(JournalTheme.Colors.negativeRedDark.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(JournalTheme.Colors.negativeRedDark.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .onAppear { refresh() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { refresh() }
        }
    }

    private func refresh() {
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        guard let raw = defaults?.array(forKey: "failureBlockedHabitInfo") as? [[String: Any]] else {
            entries = []
            return
        }
        entries = raw.compactMap { dict in
            guard let name = dict["habitName"] as? String,
                  let minutes = dict["targetMinutes"] as? Int else { return nil }
            return Entry(habitName: name, targetMinutes: minutes)
        }
    }
}
