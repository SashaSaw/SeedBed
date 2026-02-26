import SwiftUI

/// A 5-step animated tutorial overlay teaching swipe gestures and group creation
struct GestureTutorialOverlay: View {
    let onDismiss: () -> Void

    @State private var tutorialStep = 0

    // Animation states
    @State private var strikethroughProgress: CGFloat = 0
    @State private var showCompleted = false
    @State private var swipeOffset: CGFloat = 0
    @State private var showArchiveBackground = false
    @State private var longPressScale: CGFloat = 1.0
    @State private var showCheckboxes: [Bool] = [false, false, false]
    @State private var showChecks: [Bool] = [false, false, false]
    @State private var showCreateButton = false
    @State private var createButtonPressed = false
    @State private var handOffset: CGSize = .zero
    @State private var handOpacity: Double = 1.0

    private let totalSteps = 5

    var body: some View {
        ZStack {
            // Dimmed background
            Color.white.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Step title
                Text(stepTitle)
                    .font(.custom("PatrickHand-Regular", size: 26))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .id(tutorialStep)
                    .transition(.opacity)

                Spacer()
                    .frame(height: 40)

                // Animated demo area
                ZStack {
                    switch tutorialStep {
                    case 0: swipeRightDemo
                    case 1: swipeLeftDemo
                    case 2: longPressDemo
                    case 3: selectHabitsDemo
                    case 4: createGroupDemo
                    default: EmptyView()
                    }
                }
                .frame(height: 200)
                .padding(.horizontal, 32)

                Spacer()

                // Bottom action
                if tutorialStep < totalSteps - 1 {
                    Text("Tap to continue")
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                        .padding(.bottom, 60)
                } else {
                    Button {
                        Feedback.buttonPress()
                        onDismiss()
                    } label: {
                        Text("Got it!")
                            .font(.custom("PatrickHand-Regular", size: 18))
                            .foregroundStyle(.white)
                            .frame(width: 160)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(JournalTheme.Colors.inkBlue)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 60)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard tutorialStep < totalSteps - 1 else { return }
            Feedback.selection()
            advanceStep()
        }
        .onAppear {
            startAnimation()
        }
    }

    // MARK: - Step Titles

    private var stepTitle: String {
        switch tutorialStep {
        case 0: return "Swipe to cross off"
        case 1: return "Swipe left to archive"
        case 2: return "Long-press to start a group"
        case 3: return "Select habits for your group"
        case 4: return "Tap Create Group"
        default: return ""
        }
    }

    // MARK: - Step 1: Tap / Swipe Right to Complete
    // Row stays in place; a strikethrough line draws across the text and the circle fills in.
    // A hand icon demonstrates the gesture.

    private var swipeRightDemo: some View {
        ZStack(alignment: .center) {
            // The habit row — stays in place
            mockHabitRow(
                emoji: "💧",
                name: "Drink enough water",
                completed: showCompleted,
                strikethroughProgress: strikethroughProgress
            )

            // Hand indicator — finger pointing up, sweeps right across the text
            Image(systemName: "hand.point.up.fill")
                .font(.system(size: 28))
                .foregroundStyle(JournalTheme.Colors.inkBlue.opacity(0.7))
                .offset(handOffset)
                .opacity(handOpacity)
        }
    }

    // MARK: - Step 2: Swipe Left to Archive

    private var swipeLeftDemo: some View {
        ZStack {
            // Orange background that reveals behind
            if showArchiveBackground {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.2))
                    .frame(height: 52)
                    .overlay(alignment: .trailing) {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.orange)
                            .padding(.trailing, 16)
                    }
            }

            mockHabitRow(emoji: "📖", name: "Read", completed: false, strikethroughProgress: 0)
                .offset(x: swipeOffset)

            // Hand indicator — starts from right edge, sweeps left
            Image(systemName: "hand.point.up.fill")
                .font(.system(size: 28))
                .foregroundStyle(JournalTheme.Colors.inkBlue.opacity(0.7))
                .offset(handOffset)
                .opacity(handOpacity)
        }
    }

    // MARK: - Step 3: Long Press Demo
    // Long-pressing a habit enters group selection mode.
    // The completion circle is replaced by a rounded-rect checkbox on the left.

    private var longPressDemo: some View {
        ZStack {
            VStack(spacing: 8) {
                // Row that gets long-pressed — transitions from normal to selectable
                if showCheckboxes[0] {
                    mockSelectableRow(name: "Run", isSelected: showChecks[0])
                        .transition(.opacity)
                } else {
                    mockHabitRow(emoji: "🏃", name: "Run", completed: false, strikethroughProgress: 0)
                        .scaleEffect(longPressScale)
                }

                mockHabitRow(emoji: "💪", name: "Gym", completed: false, strikethroughProgress: 0)
                    .opacity(0.5)
            }

            // Hand indicator — overlaid on the whole demo, positioned on the first row
            Image(systemName: "hand.point.up.fill")
                .font(.system(size: 28))
                .foregroundStyle(JournalTheme.Colors.inkBlue.opacity(0.7))
                .offset(handOffset)
                .opacity(handOpacity)
        }
    }

    // MARK: - Step 4: Select Habits Demo
    // All rows show the rounded-rect checkbox. Tapping selects them one by one.

    private var selectHabitsDemo: some View {
        ZStack {
            VStack(spacing: 8) {
                mockSelectableRow(name: "Run", isSelected: showChecks[0])
                mockSelectableRow(name: "Gym", isSelected: showChecks[1])
                mockSelectableRow(name: "Cycle", isSelected: showChecks[2])
            }

            // Hand indicator — overlaid, moves between rows
            Image(systemName: "hand.point.up.fill")
                .font(.system(size: 28))
                .foregroundStyle(JournalTheme.Colors.inkBlue.opacity(0.7))
                .offset(handOffset)
                .opacity(handOpacity)
        }
    }

    // MARK: - Step 5: Create Group Demo

    private var createGroupDemo: some View {
        VStack(spacing: 12) {
            // Mini selected habits (all checked)
            mockSelectableRow(name: "Run", isSelected: true)
                .opacity(0.6)
            mockSelectableRow(name: "Gym", isSelected: true)
                .opacity(0.6)
            mockSelectableRow(name: "Cycle", isSelected: true)
                .opacity(0.6)

            // Create Group button
            if showCreateButton {
                ZStack {
                    Text("Create Group")
                        .font(.custom("PatrickHand-Regular", size: 17))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(JournalTheme.Colors.inkBlue)
                        )
                        .scaleEffect(createButtonPressed ? 0.95 : 1.0)

                    // Hand indicator
                    Image(systemName: "hand.point.up.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(JournalTheme.Colors.inkBlue.opacity(0.7))
                        .offset(y: 40)
                        .opacity(handOpacity)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Mock Habit Row (matches real HabitRowView)
    // Uses EmptyCheckbox circle + strikethrough line that draws across the text

    private func mockHabitRow(emoji: String, name: String, completed: Bool, strikethroughProgress: CGFloat) -> some View {
        HStack(spacing: 12) {
            // Completion indicator — empty circle or filled checkmark
            ZStack {
                Circle()
                    .strokeBorder(
                        completed ? JournalTheme.Colors.inkBlue : JournalTheme.Colors.inkBlue.opacity(0.4),
                        lineWidth: 1.5
                    )
                    .frame(width: 22, height: 22)

                if completed {
                    // Pen-style checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(JournalTheme.Colors.inkBlue)
                }
            }

            // Habit text with strikethrough overlay
            HStack(spacing: 4) {
                Text(name)
                    .font(JournalTheme.Fonts.habitName())
                    .foregroundStyle(completed ? JournalTheme.Colors.completedGray : JournalTheme.Colors.inkBlack)
            }
            .overlay(alignment: .leading) {
                // Animated strikethrough line (matches StrikethroughLine)
                if strikethroughProgress > 0 {
                    GeometryReader { geo in
                        Path { path in
                            let y = geo.size.height / 2
                            let width = geo.size.width * strikethroughProgress
                            path.move(to: CGPoint(x: 0, y: y))
                            // Slight wobble for hand-drawn feel
                            path.addCurve(
                                to: CGPoint(x: width, y: y),
                                control1: CGPoint(x: width * 0.3, y: y - 1.5),
                                control2: CGPoint(x: width * 0.7, y: y + 1.5)
                            )
                        }
                        .stroke(JournalTheme.Colors.inkBlue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JournalTheme.Colors.paperLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
        )
    }

    // MARK: - Mock Selectable Row (matches real SelectableHabitRow)
    // Rounded rectangle checkbox on the left, blue fill + white checkmark when selected

    private func mockSelectableRow(name: String, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            // Selection checkbox — rounded rectangle
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isSelected ? JournalTheme.Colors.inkBlue : JournalTheme.Colors.completedGray,
                        lineWidth: 1.5
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? JournalTheme.Colors.inkBlue : Color.clear)
                    )
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.custom("PatrickHand-Regular", size: 11))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 20, height: 20)
            }

            Text(name)
                .font(JournalTheme.Fonts.habitName())
                .foregroundStyle(JournalTheme.Colors.inkBlack)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JournalTheme.Colors.paperLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
        )
    }

    // MARK: - Animation Control

    private func advanceStep() {
        resetAnimationState()
        withAnimation(.easeInOut(duration: 0.3)) {
            tutorialStep += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            startAnimation()
        }
    }

    private func resetAnimationState() {
        strikethroughProgress = 0
        showCompleted = false
        swipeOffset = 0
        showArchiveBackground = false
        longPressScale = 1.0
        showCheckboxes = [false, false, false]
        showChecks = [false, false, false]
        showCreateButton = false
        createButtonPressed = false
        handOffset = .zero
        handOpacity = 1.0
    }

    private func startAnimation() {
        switch tutorialStep {
        case 0: animateTapComplete()
        case 1: animateSwipeLeft()
        case 2: animateLongPress()
        case 3: animateSelectHabits()
        case 4: animateCreateGroup()
        default: break
        }
    }

    // MARK: - Step Animations

    private func animateTapComplete() {
        // Start hand at the left side of the row, sweep right across the text, vertically centered
        handOffset = CGSize(width: -120, height: 0)
        handOpacity = 1.0

        withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
            handOffset = CGSize(width: 100, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            // Draw the strikethrough and fill the circle
            withAnimation(.easeInOut(duration: 0.4)) {
                showCompleted = true
                strikethroughProgress = 1.0
            }
            // Fade hand out
            withAnimation(.easeOut(duration: 0.3)) {
                handOpacity = 0
            }
        }
        // Reset and loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            guard tutorialStep == 0 else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                showCompleted = false
                strikethroughProgress = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard tutorialStep == 0 else { return }
                animateTapComplete()
            }
        }
    }

    private func animateSwipeLeft() {
        // Start hand at right edge, sweep left
        handOffset = CGSize(width: 130, height: 0)
        handOpacity = 1.0
        swipeOffset = 0

        withAnimation(.easeInOut(duration: 0.3).delay(0.3)) {
            showArchiveBackground = true
        }
        withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
            swipeOffset = -80
            handOffset = CGSize(width: -80, height: 0)
        }
        // Reset and loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            guard tutorialStep == 1 else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                swipeOffset = 0
                showArchiveBackground = false
                handOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                guard tutorialStep == 1 else { return }
                animateSwipeLeft()
            }
        }
    }

    private func animateLongPress() {
        // Hand starts centered on the first row (top half of demo area)
        handOffset = CGSize(width: 0, height: -30)
        handOpacity = 1.0

        withAnimation(.easeInOut(duration: 0.6).delay(0.3)) {
            longPressScale = 0.97
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.3)) {
                showCheckboxes[0] = true
                showChecks[0] = true
                longPressScale = 1.0
            }
            // Fade hand
            withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                handOpacity = 0
            }
        }
        // Reset and loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            guard tutorialStep == 2 else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                showCheckboxes = [false, false, false]
                showChecks = [false, false, false]
                longPressScale = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard tutorialStep == 2 else { return }
                animateLongPress()
            }
        }
    }

    private func animateSelectHabits() {
        // Hand starts on the first row, taps each one moving down
        // Row centers: first ~y:-52, second ~y:0, third ~y:52 (each row ~44pt + 8pt gap)
        handOffset = CGSize(width: 0, height: -52)
        handOpacity = 1.0

        withAnimation(.spring(response: 0.3).delay(0.2)) {
            showChecks[0] = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.3)) {
                showChecks[1] = true
                handOffset = CGSize(width: 0, height: 0)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.3)) {
                showChecks[2] = true
                handOffset = CGSize(width: 0, height: 52)
            }
        }
        // Fade hand after all selected
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                handOpacity = 0
            }
        }
    }

    private func animateCreateGroup() {
        // Button slides up
        withAnimation(.spring(response: 0.4).delay(0.3)) {
            showCreateButton = true
        }
        // Hand taps button
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.15)) {
                createButtonPressed = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.15)) {
                createButtonPressed = false
            }
        }
        // Fade hand
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                handOpacity = 0
            }
        }
    }
}
