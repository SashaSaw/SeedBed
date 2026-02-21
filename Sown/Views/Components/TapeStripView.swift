import SwiftUI

/// A decorative tape strip that looks like washi tape or masking tape
/// Used to "attach" photos in the scrapbook collage view
struct TapeStripView: View {
    var rotation: Double = 0
    var width: CGFloat = 60
    var height: CGFloat = 20

    // Cream/tan color like real masking tape
    private let tapeColor = Color(hex: "F5E6D3")
    private let tapeHighlight = Color(hex: "FAF0E4")
    private let tapeShadow = Color(hex: "E8D5C0")

    var body: some View {
        ZStack {
            // Main tape body
            RoundedRectangle(cornerRadius: 2)
                .fill(tapeColor)
                .frame(width: width, height: height)

            // Subtle texture lines (horizontal stripes)
            VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(tapeShadow.opacity(0.3))
                        .frame(width: width - 8, height: 0.5)
                }
            }

            // Highlight at top edge
            VStack {
                Rectangle()
                    .fill(tapeHighlight.opacity(0.6))
                    .frame(width: width, height: 2)
                Spacer()
            }
            .frame(height: height)

            // Torn edge effect at ends
            HStack {
                // Left torn edge
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 3, y: 2))
                    path.addLine(to: CGPoint(x: 1, y: 5))
                    path.addLine(to: CGPoint(x: 4, y: 8))
                    path.addLine(to: CGPoint(x: 2, y: 12))
                    path.addLine(to: CGPoint(x: 4, y: 15))
                    path.addLine(to: CGPoint(x: 1, y: 18))
                    path.addLine(to: CGPoint(x: 3, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .fill(Color.white.opacity(0.5))
                .frame(width: 4, height: height)

                Spacer()

                // Right torn edge
                Path { path in
                    path.move(to: CGPoint(x: 4, y: 0))
                    path.addLine(to: CGPoint(x: 1, y: 3))
                    path.addLine(to: CGPoint(x: 3, y: 6))
                    path.addLine(to: CGPoint(x: 0, y: 10))
                    path.addLine(to: CGPoint(x: 2, y: 14))
                    path.addLine(to: CGPoint(x: 0, y: 17))
                    path.addLine(to: CGPoint(x: 2, y: height))
                    path.addLine(to: CGPoint(x: 4, y: height))
                    path.closeSubpath()
                }
                .fill(Color.white.opacity(0.5))
                .frame(width: 4, height: height)
            }
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.15), radius: 2, x: 1, y: 1)
        .rotationEffect(.degrees(rotation))
    }
}

#Preview {
    VStack(spacing: 40) {
        TapeStripView()

        TapeStripView(rotation: -5, width: 70, height: 22)

        TapeStripView(rotation: 8, width: 50, height: 18)

        // On a photo preview
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray)
                .frame(width: 150, height: 100)

            VStack {
                TapeStripView(rotation: 2)
                    .offset(y: -10)
                Spacer()
            }
            .frame(height: 100)
        }
    }
    .padding()
    .background(JournalTheme.Colors.paper)
}
