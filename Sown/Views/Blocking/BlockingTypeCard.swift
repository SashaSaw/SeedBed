import SwiftUI

/// Card for selecting blocking mode: Full Block vs Timed Unlock
struct BlockingTypeCard: View {
    @State private var blockSettings = BlockSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.custom("PatrickHand-Regular", size: 15))
                    .foregroundStyle(JournalTheme.Colors.coral)

                Text("Blocking Mode")
                    .font(.custom("PatrickHand-Regular", size: 15))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
            }

            HStack(spacing: 10) {
                blockingTypePill(
                    type: .fullBlock,
                    icon: "lock.fill",
                    label: "Full Block",
                    description: "Apps completely inaccessible"
                )

                blockingTypePill(
                    type: .timedUnlock,
                    icon: "timer",
                    label: "Timed Unlock",
                    description: "Unlock for 5 min via sentence"
                )
            }

            // Explanation of selected mode
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .padding(.top, 2)

                Text(blockSettings.blockingType == .fullBlock
                    ? "Apps are completely inaccessible during your block schedule. When you try to open a blocked app, you'll be redirected to your habits."
                    : "When you try to open a blocked app, you can choose to unlock all apps for 5 minutes by typing a reflection sentence. This adds friction without fully preventing access."
                )
                    .font(.custom("PatrickHand-Regular", size: 12))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(JournalTheme.Colors.paper)
            )
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

    private func blockingTypePill(type: BlockingType, icon: String, label: String, description: String) -> some View {
        let isSelected = blockSettings.blockingType == type

        return Button {
            Feedback.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                blockSettings.blockingType = type
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? .white : JournalTheme.Colors.completedGray)

                Text(label)
                    .font(.custom("PatrickHand-Regular", size: 14))
                    .foregroundStyle(isSelected ? .white : JournalTheme.Colors.inkBlack)

                Text(description)
                    .font(.custom("PatrickHand-Regular", size: 10))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : JournalTheme.Colors.completedGray)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? JournalTheme.Colors.coral : JournalTheme.Colors.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isSelected ? Color.clear : JournalTheme.Colors.lineMedium, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
