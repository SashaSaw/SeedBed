import SwiftUI

// MARK: - Help Content Model

struct HelpItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let body: String
}

// MARK: - Help Sections

enum HelpSection {
    case todayView
    case mustDo
    case niceToDo
    case todayOnly
    case dontDo
    case blocking
    case journal
    case monthGrid
    case stats
    case settings
    case successCriteria

    var title: String {
        switch self {
        case .todayView: return "Today"
        case .mustDo: return "Must-Dos"
        case .niceToDo: return "Nice-To-Dos"
        case .todayOnly: return "Today Only"
        case .dontDo: return "Don't-Dos"
        case .blocking: return "App Blocking"
        case .journal: return "Journal"
        case .monthGrid: return "Monthly View"
        case .stats: return "Statistics"
        case .settings: return "Settings"
        case .successCriteria: return "Success Criteria"
        }
    }

    var items: [HelpItem] {
        switch self {
        case .todayView:
            return [
                HelpItem(icon: "sun.max", title: "Your daily command centre", body: "Everything you need to do today lives here — habits, tasks, and goals in one place."),
                HelpItem(icon: "hand.draw", title: "Swipe right to complete", body: "Slide a habit to the right to mark it done. You'll feel a little buzz when it counts."),
                HelpItem(icon: "hand.tap", title: "Long-press for details", body: "Press and hold any habit to see its full details, edit it, or check your history."),
            ]
        case .mustDo:
            return [
                HelpItem(icon: "star.fill", title: "Non-negotiable daily habits", body: "These are the habits you've committed to doing every single day, no excuses."),
                HelpItem(icon: "flame.fill", title: "Complete all to keep your streak", body: "Your Good Day streak only counts when every must-do is checked off."),
            ]
        case .niceToDo:
            return [
                HelpItem(icon: "leaf", title: "Bonus habits for good days", body: "Nice-to-dos are extra habits that improve your day but aren't required."),
                HelpItem(icon: "shield.checkered", title: "Won't break your streak", body: "Missing a nice-to-do won't affect your Good Day streak — no pressure."),
            ]
        case .todayOnly:
            return [
                HelpItem(icon: "clock.badge.checkmark", title: "One-off tasks for today", body: "Add tasks that only matter today — like errands or appointments."),
                HelpItem(icon: "wind", title: "Disappear tomorrow", body: "Today-only tasks are cleared at the end of the day, whether done or not."),
            ]
        case .dontDo:
            return [
                HelpItem(icon: "xmark.octagon", title: "Habits to avoid", body: "Track the things you're trying to stop doing — like doomscrolling or snacking late."),
                HelpItem(icon: "exclamationmark.triangle", title: "Mark as slipped", body: "If you give in, mark it as slipped. Honesty helps you see patterns over time."),
            ]
        case .blocking:
            return [
                HelpItem(icon: "apps.iphone", title: "Choose apps to block", body: "Select the apps and categories that distract you most during focus hours."),
                HelpItem(icon: "calendar.badge.clock", title: "Set a weekly schedule", body: "Pick which days and times blocking is active. It locks automatically."),
                HelpItem(icon: "lock.fill", title: "Countdown to unblock", body: "Once active, blocking can't be turned off until the schedule ends."),
            ]
        case .journal:
            return [
                HelpItem(icon: "pencil.line", title: "Write daily reflections", body: "Jot down how your day went — wins, struggles, or anything on your mind."),
                HelpItem(icon: "calendar", title: "Entries saved by date", body: "Each day gets its own entry. Scroll back to revisit past reflections."),
            ]
        case .monthGrid:
            return [
                HelpItem(icon: "arrow.left.arrow.right", title: "Switch between views", body: "Tap the button in the top left to toggle between your Must Do and Nice To Do habits."),
                HelpItem(icon: "paintbrush", title: "Green means a good day", body: "Green highlighted rows mean you completed all your must-do habits that day — a Good Day."),
                HelpItem(icon: "checkmark", title: "Reading the grid", body: "Checkmarks mean completed, crosses mean missed, and dashes mean the habit didn't exist yet."),
            ]
        case .stats:
            return [
                HelpItem(icon: "flame", title: "Good Day streak", body: "Track how many consecutive days you've completed all your must-do habits."),
                HelpItem(icon: "heart.fill", title: "Fulfillment trend", body: "See your daily fulfillment scores over time, based on your journal reflections."),
                HelpItem(icon: "chart.bar", title: "Bar charts vs ticks", body: "Habits with measurable targets (like '3km' or HealthKit data) show bar charts against your goal. Simple done/not-done habits show ticks and crosses over the past 7 days."),
                HelpItem(icon: "xmark.octagon", title: "Don't Do tracking", body: "Don't Do habits show your clean streak — how many days since you last slipped."),
            ]
        case .settings:
            return [
                HelpItem(icon: "bell", title: "Notifications", body: "Set up reminders so you never forget to check in on your habits."),
                HelpItem(icon: "clock", title: "Wake & bed times", body: "Your schedule helps Sown send reminders at the right moments."),
                HelpItem(icon: "icloud", title: "iCloud sync", body: "Back up your data to iCloud so it's safe and available on all your devices."),
            ]
        case .successCriteria:
            return [
                HelpItem(icon: "target", title: "Set measurable targets", body: "Define what success looks like — e.g. \"Run 3km\" or \"Read 20 pages\"."),
                HelpItem(icon: "checkmark.circle", title: "Enter actual values", body: "When you complete a habit, you'll be asked to log what you actually achieved."),
                HelpItem(icon: "chart.line.uptrend.xyaxis", title: "Track your progress", body: "Your logged values appear in Statistics so you can see improvement over time."),
            ]
        }
    }
}

// MARK: - Help Button

struct HelpButton: View {
    let section: HelpSection
    @State private var showingSheet = false

    var body: some View {
        Button {
            Feedback.selection()
            showingSheet = true
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 16))
                .foregroundStyle(JournalTheme.Colors.completedGray)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSheet) {
            HelpSheetView(section: section)
        }
    }
}

// MARK: - Help Sheet

struct HelpSheetView: View {
    let section: HelpSection
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(section.title)
                        .font(JournalTheme.Fonts.title())
                        .foregroundStyle(JournalTheme.Colors.inkBlack)
                        .padding(.bottom, 4)

                    // Help item cards
                    ForEach(section.items) { item in
                        helpItemCard(item)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .background(JournalTheme.Colors.paperLight.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Feedback.buttonPress()
                        dismiss()
                    } label: {
                        Text("Got it")
                            .font(.custom("PatrickHand-Regular", size: 16))
                            .foregroundStyle(JournalTheme.Colors.inkBlue)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func helpItemCard(_ item: HelpItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.icon)
                .font(.system(size: 18))
                .foregroundStyle(JournalTheme.Colors.amber)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.custom("PatrickHand-Regular", size: 17))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                Text(item.body)
                    .font(.custom("PatrickHand-Regular", size: 14))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JournalTheme.Colors.paperLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
        )
    }
}
