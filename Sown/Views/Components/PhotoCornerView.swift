import SwiftUI

/// Classic triangular photo album corner used to hold photos in place
/// Positioned at corners of photos in the scrapbook collage
struct PhotoCornerView: View {
    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    var corner: Corner
    var size: CGFloat = 20
    var color: Color = Color(hex: "2D3748") // Dark slate

    private var rotation: Double {
        switch corner {
        case .topLeft: return 0
        case .topRight: return 90
        case .bottomRight: return 180
        case .bottomLeft: return 270
        }
    }

    var body: some View {
        // Create the classic photo corner triangle shape
        Path { path in
            // Triangle pointing inward
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: size, y: 0))
            path.addLine(to: CGPoint(x: 0, y: size))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [color, color.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.2), radius: 1, x: 0.5, y: 0.5)
        .rotationEffect(.degrees(rotation))
    }
}

/// A view modifier that adds photo corners to all four corners of a view
struct PhotoCornersModifier: ViewModifier {
    var cornerSize: CGFloat = 16
    var color: Color = Color(hex: "2D3748")
    var showCorners: [PhotoCornerView.Corner] = [.topLeft, .topRight, .bottomLeft, .bottomRight]

    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geometry in
                ZStack {
                    if showCorners.contains(.topLeft) {
                        PhotoCornerView(corner: .topLeft, size: cornerSize, color: color)
                            .position(x: cornerSize / 2, y: cornerSize / 2)
                    }
                    if showCorners.contains(.topRight) {
                        PhotoCornerView(corner: .topRight, size: cornerSize, color: color)
                            .position(x: geometry.size.width - cornerSize / 2, y: cornerSize / 2)
                    }
                    if showCorners.contains(.bottomLeft) {
                        PhotoCornerView(corner: .bottomLeft, size: cornerSize, color: color)
                            .position(x: cornerSize / 2, y: geometry.size.height - cornerSize / 2)
                    }
                    if showCorners.contains(.bottomRight) {
                        PhotoCornerView(corner: .bottomRight, size: cornerSize, color: color)
                            .position(x: geometry.size.width - cornerSize / 2, y: geometry.size.height - cornerSize / 2)
                    }
                }
            }
        )
    }
}

extension View {
    func photoCorners(
        size: CGFloat = 16,
        color: Color = Color(hex: "2D3748"),
        corners: [PhotoCornerView.Corner] = [.topLeft, .topRight, .bottomLeft, .bottomRight]
    ) -> some View {
        modifier(PhotoCornersModifier(cornerSize: size, color: color, showCorners: corners))
    }
}

#Preview {
    VStack(spacing: 40) {
        // Individual corners
        HStack(spacing: 30) {
            PhotoCornerView(corner: .topLeft)
            PhotoCornerView(corner: .topRight)
            PhotoCornerView(corner: .bottomLeft)
            PhotoCornerView(corner: .bottomRight)
        }

        // Photo with corners
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 150, height: 100)
            .photoCorners()

        // Photo with only diagonal corners
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.blue.opacity(0.3))
            .frame(width: 150, height: 100)
            .photoCorners(corners: [.topLeft, .bottomRight])
    }
    .padding()
    .background(JournalTheme.Colors.paper)
}
