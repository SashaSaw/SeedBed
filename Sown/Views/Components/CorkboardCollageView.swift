import SwiftUI

/// A pushpin that holds photos to the corkboard
struct PushpinView: View {
    var color: Color = .red
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            // Pin head (dome shape)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.9),
                            color,
                            color.opacity(0.7)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    // Highlight reflection
                    Circle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: size * 0.3, height: size * 0.3)
                        .offset(x: -size * 0.15, y: -size * 0.15)
                )
                .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 2)

            // Pin shaft (subtle, barely visible)
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 2, height: 4)
                .offset(y: size / 2 + 1)
        }
    }
}

/// Cork texture background for the corkboard
struct CorkTextureView: View {
    var body: some View {
        ZStack {
            // Base cork color
            Color(hex: "C4A574")

            // Darker variation layer
            GeometryReader { geometry in
                Canvas { context, size in
                    // Create organic cork texture with random dots
                    for _ in 0..<200 {
                        let x = CGFloat.random(in: 0...size.width)
                        let y = CGFloat.random(in: 0...size.height)
                        let dotSize = CGFloat.random(in: 2...6)
                        let opacity = Double.random(in: 0.05...0.15)

                        let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(Color(hex: "8B7355").opacity(opacity))
                        )
                    }

                    // Add some lighter specks
                    for _ in 0..<100 {
                        let x = CGFloat.random(in: 0...size.width)
                        let y = CGFloat.random(in: 0...size.height)
                        let dotSize = CGFloat.random(in: 1...3)

                        let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(Color(hex: "D4B896").opacity(0.3))
                        )
                    }
                }
            }

            // Subtle gradient overlay for depth
            LinearGradient(
                colors: [
                    Color.black.opacity(0.05),
                    Color.clear,
                    Color.black.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

/// A photo pinned to the corkboard
struct PinnedPhotoView: View {
    let image: UIImage
    var rotation: Double = 0
    var pinColor: Color = .red
    var isExpanded: Bool = false
    var onTap: () -> Void = {}

    private let borderWidth: CGFloat = 4

    var body: some View {
        ZStack(alignment: .top) {
            // Photo with white border
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(borderWidth)
                .background(Color.white)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 3)

            // Pushpin at top center
            if !isExpanded {
                PushpinView(color: pinColor, size: 20)
                    .offset(y: -10)
            }
        }
        .rotationEffect(.degrees(isExpanded ? 0 : rotation))
        .onTapGesture {
            onTap()
        }
    }
}

/// A note card pinned to the corkboard
struct PinnedNoteView: View {
    let text: String
    var rotation: Double = -3
    var pinColor: Color = .yellow

    // Index card colors
    private let cardColor = Color(hex: "FFFEF0")
    private let lineColor = Color(hex: "ADD8E6").opacity(0.5)

    var body: some View {
        ZStack(alignment: .top) {
            // Note card with lines
            VStack(alignment: .leading, spacing: 0) {
                // Red margin line
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 2)
                    Spacer()
                }
                .frame(height: 20)

                // Content with blue lines
                ZStack(alignment: .topLeading) {
                    // Blue lines
                    VStack(spacing: 18) {
                        ForEach(0..<6, id: \.self) { _ in
                            Rectangle()
                                .fill(lineColor)
                                .frame(height: 1)
                        }
                    }
                    .padding(.top, 8)

                    // Text
                    Text(text)
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(JournalTheme.Colors.inkBlack)
                        .lineSpacing(10)
                        .padding(.leading, 20)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: 200)
            .background(cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .shadow(color: .black.opacity(0.25), radius: 3, x: 1, y: 2)

            // Pushpin
            PushpinView(color: pinColor, size: 18)
                .offset(y: -8)
        }
        .rotationEffect(.degrees(rotation))
    }
}

/// A corkboard-style collage with photos held by pushpins
struct CorkboardCollageView: View {
    let images: [UIImage]
    let note: String?

    @State private var expandedIndex: Int? = nil
    @State private var hasAppeared = false
    @State private var rotations: [Double] = []

    // Pin colors for variety
    private let pinColors: [Color] = [.red, .blue, .green, .yellow, .orange]

    private let maxPhotoHeight: CGFloat = 320

    var body: some View {
        ZStack {
            // Cork background
            CorkTextureView()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

            // Photos and note
            GeometryReader { geometry in
                let availableWidth = geometry.size.width

                ZStack {
                    // Photo layout
                    photoLayout(availableWidth: availableWidth)

                    // Note card
                    if let note = note, !note.isEmpty, expandedIndex == nil {
                        noteCard(availableWidth: availableWidth)
                    }
                }
            }
            .padding(16)
        }
        .frame(minHeight: calculateMinHeight())
        .onAppear {
            rotations = images.indices.map { index in
                generateRotation(for: index, total: images.count)
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Layouts

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

    @ViewBuilder
    private func singlePhotoLayout(availableWidth: CGFloat) -> some View {
        let photoWidth = availableWidth * 0.75
        let isExpanded = expandedIndex == 0

        VStack {
            PinnedPhotoView(
                image: images[0],
                rotation: rotations.first ?? 0,
                pinColor: pinColors[0],
                isExpanded: isExpanded,
                onTap: { toggleExpanded(0) }
            )
            .frame(maxWidth: isExpanded ? availableWidth * 0.95 : photoWidth)
            .frame(maxHeight: isExpanded ? nil : maxPhotoHeight)
            .scaleEffect(isExpanded ? 1.15 : 1.0)
            .zIndex(isExpanded ? 20 : 1)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 30)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isExpanded)

            Spacer(minLength: note != nil ? 80 : 20)
        }
    }

    @ViewBuilder
    private func twoPhotoLayout(availableWidth: CGFloat) -> some View {
        let photoWidth = availableWidth * 0.55

        ZStack {
            PinnedPhotoView(
                image: images[0],
                rotation: rotations[safe: 0] ?? -6,
                pinColor: pinColors[0],
                isExpanded: expandedIndex == 0,
                onTap: { toggleExpanded(0) }
            )
            .frame(maxWidth: expandedIndex == 0 ? availableWidth * 0.9 : photoWidth)
            .frame(maxHeight: expandedIndex == 0 ? nil : maxPhotoHeight * 0.7)
            .offset(
                x: expandedIndex == 0 ? 0 : -availableWidth * 0.15,
                y: expandedIndex == 0 ? 0 : -20
            )
            .scaleEffect(expandedIndex == 0 ? 1.15 : 1.0)
            .zIndex(expandedIndex == 0 ? 20 : 1)
            .opacity(hasAppeared ? 1 : 0)

            PinnedPhotoView(
                image: images[1],
                rotation: rotations[safe: 1] ?? 5,
                pinColor: pinColors[1],
                isExpanded: expandedIndex == 1,
                onTap: { toggleExpanded(1) }
            )
            .frame(maxWidth: expandedIndex == 1 ? availableWidth * 0.9 : photoWidth)
            .frame(maxHeight: expandedIndex == 1 ? nil : maxPhotoHeight * 0.7)
            .offset(
                x: expandedIndex == 1 ? 0 : availableWidth * 0.12,
                y: expandedIndex == 1 ? 0 : 50
            )
            .scaleEffect(expandedIndex == 1 ? 1.15 : 1.0)
            .zIndex(expandedIndex == 1 ? 20 : 2)
            .opacity(hasAppeared ? 1 : 0)
        }
        .frame(maxHeight: maxPhotoHeight + 80)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: expandedIndex)
    }

    @ViewBuilder
    private func threePhotoLayout(availableWidth: CGFloat) -> some View {
        let smallWidth = availableWidth * 0.48
        let largeWidth = availableWidth * 0.52

        ZStack {
            PinnedPhotoView(
                image: images[0],
                rotation: rotations[safe: 0] ?? -8,
                pinColor: pinColors[0],
                isExpanded: expandedIndex == 0,
                onTap: { toggleExpanded(0) }
            )
            .frame(maxWidth: expandedIndex == 0 ? availableWidth * 0.9 : smallWidth)
            .frame(maxHeight: expandedIndex == 0 ? nil : maxPhotoHeight * 0.5)
            .offset(
                x: expandedIndex == 0 ? 0 : -availableWidth * 0.18,
                y: expandedIndex == 0 ? 0 : -60
            )
            .scaleEffect(expandedIndex == 0 ? 1.15 : 1.0)
            .zIndex(expandedIndex == 0 ? 20 : 1)
            .opacity(hasAppeared ? 1 : 0)

            PinnedPhotoView(
                image: images[1],
                rotation: rotations[safe: 1] ?? 7,
                pinColor: pinColors[1],
                isExpanded: expandedIndex == 1,
                onTap: { toggleExpanded(1) }
            )
            .frame(maxWidth: expandedIndex == 1 ? availableWidth * 0.9 : smallWidth)
            .frame(maxHeight: expandedIndex == 1 ? nil : maxPhotoHeight * 0.5)
            .offset(
                x: expandedIndex == 1 ? 0 : availableWidth * 0.15,
                y: expandedIndex == 1 ? 0 : -35
            )
            .scaleEffect(expandedIndex == 1 ? 1.15 : 1.0)
            .zIndex(expandedIndex == 1 ? 20 : 2)
            .opacity(hasAppeared ? 1 : 0)

            PinnedPhotoView(
                image: images[2],
                rotation: rotations[safe: 2] ?? -2,
                pinColor: pinColors[2],
                isExpanded: expandedIndex == 2,
                onTap: { toggleExpanded(2) }
            )
            .frame(maxWidth: expandedIndex == 2 ? availableWidth * 0.9 : largeWidth)
            .frame(maxHeight: expandedIndex == 2 ? nil : maxPhotoHeight * 0.55)
            .offset(
                x: expandedIndex == 2 ? 0 : 0,
                y: expandedIndex == 2 ? 0 : 60
            )
            .scaleEffect(expandedIndex == 2 ? 1.15 : 1.0)
            .zIndex(expandedIndex == 2 ? 20 : 3)
            .opacity(hasAppeared ? 1 : 0)
        }
        .frame(maxHeight: maxPhotoHeight + 100)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: expandedIndex)
    }

    @ViewBuilder
    private func noteCard(availableWidth: CGFloat) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                PinnedNoteView(
                    text: note ?? "",
                    rotation: Double.random(in: -5.0...5.0),
                    pinColor: pinColors[images.count % pinColors.count]
                )
                .opacity(hasAppeared ? 1 : 0)
                .offset(x: hasAppeared ? 0 : 30)
            }
        }
        .padding(.trailing, 8)
        .padding(.bottom, 8)
        .zIndex(5)
    }

    // MARK: - Helpers

    private func toggleExpanded(_ index: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            expandedIndex = expandedIndex == index ? nil : index
        }
        Feedback.selection()
    }

    private func generateRotation(for index: Int, total: Int) -> Double {
        switch total {
        case 1:
            return Double.random(in: -5.0...5.0)
        case 2:
            return index == 0 ? Double.random(in: -8.0...(-3.0)) : Double.random(in: 3.0...8.0)
        case 3:
            switch index {
            case 0: return Double.random(in: -10.0...(-4.0))
            case 1: return Double.random(in: 4.0...10.0)
            default: return Double.random(in: -3.0...3.0)
            }
        default:
            return 0
        }
    }

    private func calculateMinHeight() -> CGFloat {
        let base: CGFloat
        switch images.count {
        case 1: base = maxPhotoHeight + 60
        case 2: base = maxPhotoHeight + 120
        case 3: base = maxPhotoHeight + 150
        default: base = 200
        }
        return note != nil ? base + 80 : base
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
        VStack(spacing: 30) {
            Text("Corkboard Style")
                .font(JournalTheme.Fonts.title())

            if let image = createCorkboardPreviewImage() {
                CorkboardCollageView(
                    images: [image],
                    note: "Remember this day!"
                )
                .frame(height: 480)
                .padding(.horizontal)

                CorkboardCollageView(
                    images: [image, image],
                    note: "Great memories"
                )
                .frame(height: 520)
                .padding(.horizontal)

                CorkboardCollageView(
                    images: [image, image, image],
                    note: "Best trip ever"
                )
                .frame(height: 560)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    .background(JournalTheme.Colors.paper)
}

private func createCorkboardPreviewImage() -> UIImage? {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 280, height: 200))
    return renderer.image { context in
        UIColor.systemIndigo.withAlphaComponent(0.3).setFill()
        context.fill(CGRect(x: 0, y: 0, width: 280, height: 200))
    }
}
