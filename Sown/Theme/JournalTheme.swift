import SwiftUI
import UIKit

/// Theme constants for the journal aesthetic
enum JournalTheme {
    // MARK: - Colors

    enum Colors {
        static let paper = Color(hex: "FDF8E7")
        static let paperDark = Color(hex: "F5EED6")
        static let lineLight = Color(hex: "D4D4D4")
        static let lineMedium = Color(hex: "B8C4CE")
        static let inkBlue = Color(hex: "1A365D")
        static let inkBlack = Color(hex: "2D2D2D")
        static let goodDayGreen = Color(hex: "C6F6D5")
        static let goodDayGreenDark = Color(hex: "68D391")
        static let negativeRed = Color(hex: "FED7D7")
        static let negativeRedDark = Color(hex: "FC8181")
        static let completedGray = Color(hex: "A0AEC0")
        static let sectionHeader = Color(hex: "4A5568")

        // New color system from redesign
        static let amber = Color(hex: "D4A028")           // Must-do labels, streak bar incomplete
        static let teal = Color(hex: "4A9B8E")            // Today-only tasks, badges, task checkboxes
        static let successGreen = Color(hex: "5B9A5F")    // Streak bar complete, success states
        static let navy = Color(hex: "1E2A4A")            // Core UI, checkmarks, primary text
        static let coral = Color(hex: "D4836A")           // Blocked apps, quit habit, archive
        static let paperLight = Color(hex: "FAF6EC")       // Card backgrounds, input backgrounds
        static let purple = Color(hex: "7C3AED")          // Screen Time integration, app usage
    }

    // MARK: - Fonts

    enum Fonts {
        /// The custom handwritten font name
        private static let patrickHand = "PatrickHand-Regular"

        static func handwritten(size: CGFloat) -> Font {
            .custom(patrickHand, size: size)
        }

        static func typewriter(size: CGFloat) -> Font {
            .system(size: size, weight: .regular, design: .monospaced)
        }

        static func title() -> Font {
            .custom(patrickHand, size: 30)
        }

        static func dateHeader() -> Font {
            .custom(patrickHand, size: 24)
        }

        static func sectionHeader() -> Font {
            .custom(patrickHand, size: 15)
        }

        static func habitName() -> Font {
            .custom(patrickHand, size: 19)
        }

        static func habitCriteria() -> Font {
            .custom(patrickHand, size: 16)
        }

        static func streakCount() -> Font {
            .custom(patrickHand, size: 14)
        }
    }

    // MARK: - Dimensions

    enum Dimensions {
        static let lineSpacing: CGFloat = 32
        static let marginLeft: CGFloat = 48
        static let gridCellSize: CGFloat = 32
        static let cornerRadius: CGFloat = 8
        static let strokeWidth: CGFloat = 2
        static let checkmarkSize: CGFloat = 24
    }

    // MARK: - Animations

    enum Animations {
        static let strikethrough = Animation.easeOut(duration: 0.3)
        static let completion = Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let fade = Animation.easeInOut(duration: 0.2)
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Unified Feedback (Haptics + Sound)

/// Combined haptic + sound feedback. Call these instead of HapticFeedback directly.
/// Sound can be toggled off in Settings; haptics always fire.
///
/// Generators are created once and reused — creating a new UIFeedbackGenerator per call
/// triggers an XPC connection to hapticd each time, which can block the main thread for
/// hundreds of milliseconds when the daemon is slow (e.g. first launch).
enum Feedback {
    private static let sound = SoundEffectService.shared

    // Reusable generators — created once, prepared once
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let selectionGen = UISelectionFeedbackGenerator()
    private static let notificationGen = UINotificationFeedbackGenerator()

    /// Call early (e.g. in SownApp.init) to kick off haptic engine preparation.
    /// Runs asynchronously so it doesn't block app startup — each prepare() call
    /// involves an XPC round-trip to hapticd that can block for seconds.
    static func warmUp() {
        DispatchQueue.main.async {
            lightImpact.prepare()
            mediumImpact.prepare()
            selectionGen.prepare()
            notificationGen.prepare()
        }
    }

    // === Original feedback types (1:1 replacements for HapticFeedback) ===

    /// Light impact + completion sound (habit tap-to-complete)
    static func completion() {
        lightImpact.impactOccurred()
        sound.completion()
    }

    /// Notification success + success chime (habit saved, onboarding complete)
    static func success() {
        notificationGen.notificationOccurred(.success)
        sound.successSound()
    }

    /// Selection changed + light click (toggles, pills, general taps)
    static func selection() {
        selectionGen.selectionChanged()
        sound.selection()
    }

    /// Medium impact + threshold click (swipe passes commit point)
    static func thresholdCrossed() {
        mediumImpact.impactOccurred(intensity: 0.7)
        sound.thresholdCrossed()
    }

    /// Strong success + completion sound (final swipe confirm)
    static func completionConfirmed() {
        notificationGen.notificationOccurred(.success)
        sound.completion()
    }

    // === New feedback types (richer sound categories) ===

    /// Good day achieved! Strong haptic + custom celebration fanfare.
    static func celebration() {
        notificationGen.notificationOccurred(.success)
        sound.celebration()
    }

    /// Negative habit slipped. Medium impact + warning tone.
    static func slip() {
        mediumImpact.impactOccurred()
        sound.slip()
    }

    /// Undo action. Light impact + subtle reverse sound.
    static func undo() {
        lightImpact.impactOccurred()
        sound.undo()
    }

    /// Archive confirmed. Medium impact + swoosh.
    static func archive() {
        mediumImpact.impactOccurred()
        sound.archive()
    }

    /// Delete confirmed. Medium impact + delete tone.
    static func delete() {
        mediumImpact.impactOccurred()
        sound.deleteSound()
    }

    /// Tab bar switched. Sound only, no haptic.
    static func tabSwitch() {
        sound.tabSwitch()
    }

    /// Sheet/modal opened. Sound only, no haptic.
    static func sheetOpen() {
        sound.sheetOpen()
    }

    /// Button pressed (add habit, toolbar). Light impact + tap.
    static func buttonPress() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        sound.buttonPress()
    }

    /// Long press confirmed. Medium impact + subtle thud.
    static func longPress() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        sound.longPress()
    }

    /// Group expand/collapse. Light impact + click.
    static func groupToggle() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        sound.groupToggle()
    }

    // === Swipe gesture sounds ===

    /// Start looping swipe sound (call when drag begins)
    static func startSwiping() {
        sound.startSwiping()
    }

    /// Stop looping swipe sound (call if needed manually)
    static func stopSwiping() {
        sound.stopSwiping()
    }

    /// Swipe completed successfully. Stops loop + plays completion sound.
    static func swipeCompleted() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        sound.swipeCompleted()
    }

    /// Swipe cancelled. Stops loop + plays cancel sound.
    static func swipeCancelled() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        sound.swipeCancelled()
    }

    /// Success criteria saved. Light impact + ding sound.
    static func ding() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        sound.ding()
    }
}
