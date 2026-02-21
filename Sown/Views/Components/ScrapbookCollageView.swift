import SwiftUI

/// A scrapbook-style collage view that displays photos in an overlapping, rotated arrangement
/// Supports 1-3 photos with tap-to-expand functionality and a sticky note for captions
struct ScrapbookCollageView: View {
    let images: [UIImage]
    let note: String?

    @State private var expandedIndex: Int? = nil
    @State private var hasAppeared = false

    // Layout constants
    private let maxPhotoHeight: CGFloat = 380
    private let overlapRatio: CGFloat = 0.20

    // Pre-computed rotations for consistent layout
    private var rotations: [Double] {
        switch images.count {
        case 1:
            return [Double.random(in: -3.0...3.0)]
        case 2:
            return [
                Double.random(in: -5.0...(-2.0)),
                Double.random(in: 2.0...5.0)
            ]
        case 3:
            return [
                Double.random(in: -6.0...(-3.0)),
                Double.random(in: 3.0...6.0),
                Double.random(in: -2.0...2.0)
            ]
        default:
            return []
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width

            ZStack {
                // Dim overlay when photo is expanded
                if expandedIndex != nil {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                expandedIndex = nil
                            }
                        }
                        .zIndex(10)
                }

                // Photos layout
                photoLayout(availableWidth: availableWidth)

                // Sticky note at bottom
                if let note = note, !note.isEmpty, expandedIndex == nil {
                    VStack {
                        Spacer()
                        StickyNoteView(
                            text: note,
                            rotation: Double.random(in: -3.0...2.0),
                            maxWidth: min(availableWidth - 40, 280)
                        )
                        .offset(x: 20, y: -10)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(x: hasAppeared ? 0 : 50)
                    }
                    .zIndex(5)
                }
            }
        }
        .frame(minHeight: calculateMinHeight())
        .onAppear {
            // Entrance animation
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Photo Layouts

    @ViewBuilder
    private func photoLayout(availableWidth: CGFloat) -> some View {
        switch images.count {
        case 1:
            singlePhotoLayout(availableWidth: availableWidth)
        case 2:
            twoPhotoLayout(availableWidth: availableWidth)
        case 3:
            threePhotoLayout(availableWidth: availableWidth)
        default:
            EmptyView()
        }
    }

    // MARK: Single Photo Layout

    @ViewBuilder
    private func singlePhotoLayout(availableWidth: CGFloat) -> some View {
        let photoWidth = availableWidth * 0.85
        let isExpanded = expandedIndex == 0

        VStack {
            ScrapbookPhotoView(
                image: images[0],
                index: 0,
                totalCount: 1,
                rotation: rotations.first ?? 0,
                isExpanded: isExpanded,
                onTap: { toggleExpanded(0) }
            )
            .frame(maxWidth: isExpanded ? availableWidth : photoWidth)
            .frame(maxHeight: isExpanded ? nil : maxPhotoHeight)
            .scaleEffect(isExpanded ? 1.1 : 1.0)
            .zIndex(isExpanded ? 20 : 1)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 30)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isExpanded)

            Spacer(minLength: note != nil ? 100 : 20)
        }
    }

    // MARK: Two Photo Layout

    @ViewBuilder
    private func twoPhotoLayout(availableWidth: CGFloat) -> some View {
        let photoWidth = availableWidth * 0.65
        let verticalOverlap: CGFloat = 60

        ZStack {
            // Photo 1: Upper left
            ScrapbookPhotoView(
                image: images[0],
                index: 0,
                totalCount: 2,
                rotation: rotations[safe: 0] ?? -3,
                isExpanded: expandedIndex == 0,
                onTap: { toggleExpanded(0) }
            )
            .frame(maxWidth: expandedIndex == 0 ? availableWidth * 0.9 : photoWidth)
            .frame(maxHeight: expandedIndex == 0 ? nil : maxPhotoHeight * 0.7)
            .offset(
                x: expandedIndex == 0 ? 0 : -availableWidth * 0.12,
                y: expandedIndex == 0 ? 0 : -verticalOverlap
            )
            .scaleEffect(expandedIndex == 0 ? 1.15 : 1.0)
            .zIndex(expandedIndex == 0 ? 20 : 1)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 40)
            .animation(
                .spring(response: 0.35, dampingFraction: 0.7)
                    .delay(hasAppeared ? 0 : 0.05),
                value: expandedIndex
            )

            // Photo 2: Lower right
            ScrapbookPhotoView(
                image: images[1],
                index: 1,
                totalCount: 2,
                rotation: rotations[safe: 1] ?? 3,
                isExpanded: expandedIndex == 1,
                onTap: { toggleExpanded(1) }
            )
            .frame(maxWidth: expandedIndex == 1 ? availableWidth * 0.9 : photoWidth)
            .frame(maxHeight: expandedIndex == 1 ? nil : maxPhotoHeight * 0.7)
            .offset(
                x: expandedIndex == 1 ? 0 : availableWidth * 0.12,
                y: expandedIndex == 1 ? 0 : verticalOverlap
            )
            .scaleEffect(expandedIndex == 1 ? 1.15 : 1.0)
            .zIndex(expandedIndex == 1 ? 20 : 2)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 50)
            .animation(
                .spring(response: 0.35, dampingFraction: 0.7)
                    .delay(hasAppeared ? 0 : 0.1),
                value: expandedIndex
            )
        }
        .frame(maxHeight: maxPhotoHeight + 80)
    }

    // MARK: Three Photo Layout

    @ViewBuilder
    private func threePhotoLayout(availableWidth: CGFloat) -> some View {
        let smallPhotoWidth = availableWidth * 0.52
        let largePhotoWidth = availableWidth * 0.60

        ZStack {
            // Photo 1: Top left
            ScrapbookPhotoView(
                image: images[0],
                index: 0,
                totalCount: 3,
                rotation: rotations[safe: 0] ?? -4,
                isExpanded: expandedIndex == 0,
                onTap: { toggleExpanded(0) }
            )
            .frame(maxWidth: expandedIndex == 0 ? availableWidth * 0.9 : smallPhotoWidth)
            .frame(maxHeight: expandedIndex == 0 ? nil : maxPhotoHeight * 0.55)
            .offset(
                x: expandedIndex == 0 ? 0 : -availableWidth * 0.18,
                y: expandedIndex == 0 ? 0 : -80
            )
            .scaleEffect(expandedIndex == 0 ? 1.15 : 1.0)
            .zIndex(expandedIndex == 0 ? 20 : 1)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 40)
            .animation(
                .spring(response: 0.35, dampingFraction: 0.7)
                    .delay(hasAppeared ? 0 : 0.0),
                value: expandedIndex
            )

            // Photo 2: Top right
            ScrapbookPhotoView(
                image: images[1],
                index: 1,
                totalCount: 3,
                rotation: rotations[safe: 1] ?? 4,
                isExpanded: expandedIndex == 1,
                onTap: { toggleExpanded(1) }
            )
            .frame(maxWidth: expandedIndex == 1 ? availableWidth * 0.9 : smallPhotoWidth)
            .frame(maxHeight: expandedIndex == 1 ? nil : maxPhotoHeight * 0.55)
            .offset(
                x: expandedIndex == 1 ? 0 : availableWidth * 0.18,
                y: expandedIndex == 1 ? 0 : -60
            )
            .scaleEffect(expandedIndex == 1 ? 1.15 : 1.0)
            .zIndex(expandedIndex == 1 ? 20 : 2)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 50)
            .animation(
                .spring(response: 0.35, dampingFraction: 0.7)
                    .delay(hasAppeared ? 0 : 0.05),
                value: expandedIndex
            )

            // Photo 3: Bottom center, overlapping both
            ScrapbookPhotoView(
                image: images[2],
                index: 2,
                totalCount: 3,
                rotation: rotations[safe: 2] ?? 0,
                isExpanded: expandedIndex == 2,
                onTap: { toggleExpanded(2) }
            )
            .frame(maxWidth: expandedIndex == 2 ? availableWidth * 0.9 : largePhotoWidth)
            .frame(maxHeight: expandedIndex == 2 ? nil : maxPhotoHeight * 0.6)
            .offset(
                x: expandedIndex == 2 ? 0 : 0,
                y: expandedIndex == 2 ? 0 : 70
            )
            .scaleEffect(expandedIndex == 2 ? 1.15 : 1.0)
            .zIndex(expandedIndex == 2 ? 20 : 3)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 60)
            .animation(
                .spring(response: 0.35, dampingFraction: 0.7)
                    .delay(hasAppeared ? 0 : 0.1),
                value: expandedIndex
            )
        }
        .frame(maxHeight: maxPhotoHeight + 100)
    }

    // MARK: - Helpers

    private func toggleExpanded(_ index: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            if expandedIndex == index {
                expandedIndex = nil
            } else {
                expandedIndex = index
            }
        }
        Feedback.selection()
    }

    private func calculateMinHeight() -> CGFloat {
        let baseHeight: CGFloat
        switch images.count {
        case 1: baseHeight = maxPhotoHeight + 40
        case 2: baseHeight = maxPhotoHeight + 120
        case 3: baseHeight = maxPhotoHeight + 180
        default: baseHeight = 200
        }
        return note != nil ? baseHeight + 100 : baseHeight
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 60) {
            // Preview with placeholder images
            Text("1 Photo")
                .font(JournalTheme.Fonts.sectionHeader())

            if let image = createPlaceholderImage() {
                ScrapbookCollageView(
                    images: [image],
                    note: "A beautiful day at the park!"
                )
                .frame(height: 500)
            }

            Divider()

            Text("2 Photos")
                .font(JournalTheme.Fonts.sectionHeader())

            if let image = createPlaceholderImage() {
                ScrapbookCollageView(
                    images: [image, image],
                    note: "Fun times with friends"
                )
                .frame(height: 550)
            }

            Divider()

            Text("3 Photos")
                .font(JournalTheme.Fonts.sectionHeader())

            if let image = createPlaceholderImage() {
                ScrapbookCollageView(
                    images: [image, image, image],
                    note: "An amazing adventure!"
                )
                .frame(height: 620)
            }
        }
        .padding()
    }
    .background(JournalTheme.Colors.paper)
}

private func createPlaceholderImage() -> UIImage? {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 200))
    return renderer.image { context in
        UIColor.systemGray4.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 300, height: 200))

        // Draw a simple camera icon
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 50),
            .foregroundColor: UIColor.systemGray2,
            .paragraphStyle: paragraphStyle
        ]
        let string = "📷"
        string.draw(with: CGRect(x: 0, y: 70, width: 300, height: 60), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    }
}
