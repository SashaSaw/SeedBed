import SwiftUI

/// Dedicated Block tab — dashboard for managing app blocking
struct BlockTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LinedPaperBackground(lineSpacing: JournalTheme.Dimensions.lineSpacing)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Block Apps")
                                .font(JournalTheme.Fonts.title())
                                .foregroundStyle(JournalTheme.Colors.inkBlack)

                            Text("Stay focused by blocking distracting apps")
                                .font(JournalTheme.Fonts.habitCriteria())
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                        }

                        BlockStatusCard()
                        FailureBlockBanner()
                        BlockingTypeCard()
                        ScheduleCard()
                        BlockedAppsCard()
                        infoCallout

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HelpButton(section: .blocking)
                }
            }
        }
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
    BlockTabView()
}
