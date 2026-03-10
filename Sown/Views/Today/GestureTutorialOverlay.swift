import SwiftUI

/// A 6-step animated tutorial overlay teaching swipe gestures, tap-to-edit, and group creation
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
    @State private var tapEditHighlight: Bool = false
    @State private var showEditSheet: Bool = false

    private let totalSteps = 6

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
                    case 1: tapToEditDemo
                    case 2: swipeLeftDemo
                    case 3: longPressDemo
                    case 4: selectHabitsDemo
                    case 5: createGroupDemo
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
        case 1: return "Tap to see details"
        case 2: return "Swipe left to archive"
        case 3: return "Long-press to start a group"
        case 4: return "Select habits for your group"
        case 5: return "Tap Create Group"
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

    // MARK: - Step 2: Tap to See Details
    // Hand taps the row, row highlights, a mock detail card peeks up from the bottom.

    private var tapToEditDemo: some View {
        ZStack {
            VStack(spacing: 0) {
                mockHabitRow(
                    emoji: "💧",
                    name: "Drink enough water",
                    completed: false,
                    strikethroughProgress: 0
                )
                .scaleEffect(tapEditHighlight ? 0.97 : 1.0)
                .brightness(tapEditHighlight ? -0.03 : 0)

                Spacer().frame(height: 16)

                // Mock detail card that peeks up
                if showEditSheet {
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(JournalTheme.Colors.completedGray.opacity(0.4))
                            .frame(width: 36, height: 4)
                            .padding(.top, 8)

                        Text("Edit habit")
                            .font(.custom("PatrickHand-Regular", size: 16))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)
                            .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(JournalTheme.Colors.paperLight)
                            .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Hand indicator
            Image(systemName: "hand.point.up.fill")
                .font(.system(size: 28))
                .foregroundStyle(JournalTheme.Colors.inkBlue.opacity(0.7))
                .offset(handOffset)
                .opacity(handOpacity)
        }
    }

    // MARK: - Step 3: Swipe Left to Archive

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

    // MARK: - Step 4: Long Press Demo
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

    // MARK: - Step 5: Select Habits Demo
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

    // MARK: - Step 6: Create Group Demo

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
            // Bullet dot
            Circle()
                .fill(completed
                    ? JournalTheme.Colors.completedGray
                    : JournalTheme.Colors.inkBlack)
                .frame(width: 6, height: 6)

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
        tapEditHighlight = false
        showEditSheet = false
    }

    private func startAnimation() {
        switch tutorialStep {
        case 0: animateTapComplete()
        case 1: animateTapToEdit()
        case 2: animateSwipeLeft()
        case 3: animateLongPress()
        case 4: animateSelectHabits()
        case 5: animateCreateGroup()
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

    private func animateTapToEdit() {
        // Hand starts above the row, moves down to tap it
        handOffset = CGSize(width: 0, height: -40)
        handOpacity = 1.0

        // Hand moves to center of row
        withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
            handOffset = CGSize(width: 0, height: 0)
        }
        // Tap effect — highlight the row
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.12)) {
                tapEditHighlight = true
            }
        }
        // Release tap
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeInOut(duration: 0.12)) {
                tapEditHighlight = false
            }
            // Show the mock detail card peeking up
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showEditSheet = true
            }
            // Fade hand out
            withAnimation(.easeOut(duration: 0.3)) {
                handOpacity = 0
            }
        }
        // Reset and loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            guard tutorialStep == 1 else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                showEditSheet = false
                tapEditHighlight = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard tutorialStep == 1 else { return }
                animateTapToEdit()
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
            guard tutorialStep == 2 else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                swipeOffset = 0
                showArchiveBackground = false
                handOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                guard tutorialStep == 2 else { return }
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
            guard tutorialStep == 3 else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                showCheckboxes = [false, false, false]
                showChecks = [false, false, false]
                longPressScale = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard tutorialStep == 3 else { return }
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
