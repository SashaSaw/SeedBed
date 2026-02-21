import SwiftUI

/// An individual photo in the scrapbook collage with decorative elements
/// Features rotation, white border (mat), shadows, and optional tape/corners
struct ScrapbookPhotoView: View {
    let image: UIImage
    let index: Int
    let totalCount: Int

    var rotation: Double = 0
    var isExpanded: Bool = false
    var onTap: () -> Void = {}

    // Photo mat/border settings
    private let borderWidth: CGFloat = 8
    private let shadowRadius: CGFloat = 8

    /// Determines which decoration to show based on photo index
    private var decorationType: DecorationType {
        // Alternate between tape and corners based on index
        switch index % 3 {
        case 0: return .tape
        case 1: return .cornersOpposite
        default: return .cornersAll
        }
    }

    enum DecorationType {
        case tape
        case cornersOpposite // Diagonal corners only
        case cornersAll
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Photo with white border (mat effect)
            photoWithMat

            // Tape decoration at top
            if decorationType == .tape && !isExpanded {
                TapeStripView(rotation: Double.random(in: -5.0...5.0), width: 65, height: 20)
                    .offset(y: -10)
            }
        }
        .onTapGesture {
            onTap()
        }
    }

    @ViewBuilder
    private var photoWithMat: some View {
        // The image with white mat border
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .background(Color.white)
            .padding(borderWidth)
            .background(
                Rectangle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.2), radius: shadowRadius, x: 2, y: 4)
            )
            .overlay(
                // Subtle inner shadow on the mat
                Rectangle()
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .applyCorners(decorationType: decorationType, isExpanded: isExpanded)
            .rotationEffect(.degrees(isExpanded ? 0 : rotation))
    }
}

// MARK: - Corner Decoration Extension

private extension View {
    @ViewBuilder
    func applyCorners(decorationType: ScrapbookPhotoView.DecorationType, isExpanded: Bool) -> some View {
        if isExpanded {
            self
        } else {
            switch decorationType {
            case .tape:
                self
            case .cornersOpposite:
                self.photoCorners(size: 14, corners: [.topLeft, .bottomRight])
            case .cornersAll:
                self.photoCorners(size: 12)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 40) {
            // Single photo with tape
            if let image = UIImage(systemName: "photo.fill")?.withTintColor(.gray, renderingMode: .alwaysOriginal) {
                ScrapbookPhotoView(
                    image: image,
                    index: 0,
                    totalCount: 1,
                    rotation: -3
                )
                .frame(width: 200, height: 150)

                ScrapbookPhotoView(
                    image: image,
                    index: 1,
                    totalCount: 2,
                    rotation: 4
                )
                .frame(width: 180, height: 140)

                ScrapbookPhotoView(
                    image: image,
                    index: 2,
                    totalCount: 3,
                    rotation: -2
                )
                .frame(width: 160, height: 120)
            }
        }
        .padding(40)
    }
    .background(JournalTheme.Colors.paper)
}
