import SwiftUI

/// A yellow sticky note view for displaying captions and notes in the scrapbook
/// Features a folded corner shadow effect and handwritten font
struct StickyNoteView: View {
    let text: String
    var rotation: Double = -2
    var maxWidth: CGFloat = 200

    // Classic sticky note yellow
    private let noteColor = Color(hex: "FFF9C4")
    private let noteShadow = Color(hex: "F0E68C")
    private let foldColor = Color(hex: "E6DC82")

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main note body
            VStack(alignment: .leading, spacing: 0) {
                // Top fold shadow area
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [noteShadow.opacity(0.5), noteColor],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 6)

                // Note content
                Text(text)
                    .font(.custom("PatrickHand-Regular", size: 16))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                    .lineSpacing(4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: maxWidth, alignment: .leading)
            }
            .background(noteColor)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 3)

            // Folded corner effect (top right)
            Path { path in
                let foldSize: CGFloat = 14
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: foldSize, y: 0))
                path.addLine(to: CGPoint(x: 0, y: foldSize))
                path.closeSubpath()
            }
            .fill(foldColor)
            .frame(width: 14, height: 14)
            .shadow(color: .black.opacity(0.1), radius: 1, x: -1, y: 1)
        }
        .rotationEffect(.degrees(rotation))
    }
}

/// A smaller inline sticky note variant for shorter captions
struct MiniStickyNoteView: View {
    let text: String
    var rotation: Double = 0

    private let noteColor = Color(hex: "FFF9C4")

    var body: some View {
        Text(text)
            .font(.custom("PatrickHand-Regular", size: 14))
            .foregroundStyle(JournalTheme.Colors.inkBlack)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(noteColor)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 2)
            )
            .rotationEffect(.degrees(rotation))
    }
}

#Preview {
    VStack(spacing: 30) {
        StickyNoteView(
            text: "Beautiful sunset at the beach! Can't believe how peaceful it was.",
            rotation: -3
        )

        StickyNoteView(
            text: "First attempt at watercolors",
            rotation: 2,
            maxWidth: 150
        )

        MiniStickyNoteView(text: "June 2024", rotation: -1)

        // On paper background
        ZStack {
            JournalTheme.Colors.paper
            VStack {
                Spacer()
                StickyNoteView(
                    text: "This was such a fun day! We should do this more often.",
                    rotation: -2,
                    maxWidth: 220
                )
                .padding(.bottom, 20)
            }
        }
        .frame(height: 200)
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
