import SwiftUI
import WidgetKit

// MARK: - Widget Colors & Fonts

private enum WidgetTheme {
    static let paper = Color(red: 253/255, green: 248/255, blue: 231/255)       // #FDF8E7
    static let navy = Color(red: 30/255, green: 42/255, blue: 74/255)           // #1E2A4A
    static let amber = Color(red: 212/255, green: 160/255, blue: 40/255)        // #D4A028
    static let blockingRed = Color(red: 220/255, green: 53/255, blue: 53/255)   // #DC3535
    static let successGreen = Color(red: 91/255, green: 154/255, blue: 95/255)  // #5B9A5F
    static let completedGray = Color(red: 160/255, green: 174/255, blue: 192/255) // #A0AEC0
    static let lineLight = Color(red: 212/255, green: 212/255, blue: 212/255)   // #D4D4D4
    static let marginRed = Color(red: 252/255, green: 129/255, blue: 129/255)   // #FC8181

    static func handwritten(_ size: CGFloat) -> Font {
        .custom("PatrickHand-Regular", size: size)
    }
}

// MARK: - Lined Paper Widget Background

private struct WidgetLinedPaper: View {
    var lineSpacing: CGFloat = 22

    var body: some View {
        ZStack {
            WidgetTheme.paper

            Canvas { context, size in
                // Horizontal ruled lines
                let lineColor = WidgetTheme.lineLight.resolve(in: .init())
                var y = lineSpacing
                while y < size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(Color(lineColor)), lineWidth: 0.5)
                    y += lineSpacing
                }

                // Left margin line
                let marginColor = WidgetTheme.marginRed.opacity(0.3).resolve(in: .init())
                var marginPath = Path()
                marginPath.move(to: CGPoint(x: 32, y: 0))
                marginPath.addLine(to: CGPoint(x: 32, y: size.height))
                context.stroke(marginPath, with: .color(Color(marginColor)), lineWidth: 0.5)
            }

            // Subtle paper texture
            LinearGradient(
                colors: [
                    Color.black.opacity(0.02),
                    Color.clear,
                    Color.black.opacity(0.01)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.03)
        }
    }
}

// MARK: - Large Widget

struct SownWidgetLargeView: View {
    let data: WidgetHabitData

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: date on left, streak + blocking on right
            HStack {
                Text(formattedDate)
                    .font(WidgetTheme.handwritten(16))
                    .foregroundStyle(WidgetTheme.navy)

                Spacer()

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(WidgetTheme.amber)
                            .font(.system(size: 16))
                        Text("\(data.streakCount)")
                            .font(WidgetTheme.handwritten(18))
                            .foregroundStyle(WidgetTheme.navy)
                    }

                    Image(systemName: data.isBlockingActive ? "lock.fill" : "lock.open.fill")
                        .foregroundStyle(data.isBlockingActive ? WidgetTheme.blockingRed : WidgetTheme.successGreen)
                        .font(.system(size: 14))
                }
            }

            Divider()
                .overlay(WidgetTheme.completedGray.opacity(0.4))

            // Today Tasks section (one-off tasks)
            let incompleteTodayTasks = data.todayTasks.filter { !$0.isCompleted }
            if !incompleteTodayTasks.isEmpty {
                Text("Today")
                    .font(WidgetTheme.handwritten(14))
                    .foregroundStyle(WidgetTheme.successGreen)

                ForEach(Array(incompleteTodayTasks.prefix(3)), id: \.id) { task in
                    taskRow(task)
                }
            }

            // Must Do section (remaining incomplete)
            let incompleteMustDo = data.mustDoTasks.filter { !$0.isCompleted }
            if !incompleteMustDo.isEmpty {
                Text("Must Do")
                    .font(WidgetTheme.handwritten(14))
                    .foregroundStyle(WidgetTheme.amber)
                    .padding(.top, incompleteTodayTasks.isEmpty ? 0 : 2)

                ForEach(Array(incompleteMustDo.prefix(3)), id: \.id) { task in
                    taskRow(task)
                }
            }

            // Nice To Do section (remaining incomplete)
            let incompleteNiceToDo = data.niceToDoTasks.filter { !$0.isCompleted }
            if !incompleteNiceToDo.isEmpty {
                Text("Nice To Do")
                    .font(WidgetTheme.handwritten(14))
                    .foregroundStyle(WidgetTheme.navy.opacity(0.6))
                    .padding(.top, 2)

                ForEach(Array(incompleteNiceToDo.prefix(2)), id: \.id) { task in
                    taskRow(task)
                }
            }

            // All done state
            if incompleteTodayTasks.isEmpty && incompleteMustDo.isEmpty && incompleteNiceToDo.isEmpty && data.totalCount > 0 {
                Spacer()
                Text("✓ All done!")
                    .font(WidgetTheme.handwritten(18))
                    .foregroundStyle(WidgetTheme.successGreen)
                    .frame(maxWidth: .infinity)
                Spacer()
            }

            Spacer(minLength: 0)

            // Progress footer
            Text("\(data.completedCount) of \(data.totalCount) done today")
                .font(WidgetTheme.handwritten(13))
                .foregroundStyle(WidgetTheme.completedGray)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            WidgetLinedPaper()
        }
        .widgetURL(URL(string: "sown://today"))
    }

    private func taskRow(_ task: WidgetTask) -> some View {
        HStack(spacing: 6) {
            Text("•")
                .font(WidgetTheme.handwritten(14))
                .foregroundStyle(task.isCompleted ? WidgetTheme.successGreen : WidgetTheme.navy.opacity(0.6))

            Text(task.name)
                .font(WidgetTheme.handwritten(14))
                .foregroundStyle(task.isCompleted ? WidgetTheme.completedGray : WidgetTheme.navy)
                .strikethrough(task.isCompleted)
                .lineLimit(1)

            Spacer()
        }
    }

}

// MARK: - Medium Widget

struct SownWidgetMediumView: View {
    let data: WidgetHabitData

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Top row: date on left, streak on right
            HStack {
                Text(formattedDate)
                    .font(WidgetTheme.handwritten(14))
                    .foregroundStyle(WidgetTheme.navy)

                Spacer()

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(WidgetTheme.amber)
                            .font(.system(size: 14))
                        Text("\(data.streakCount)")
                            .font(WidgetTheme.handwritten(16))
                            .foregroundStyle(WidgetTheme.navy)
                    }

                    Image(systemName: data.isBlockingActive ? "lock.fill" : "lock.open.fill")
                        .foregroundStyle(data.isBlockingActive ? WidgetTheme.blockingRed : WidgetTheme.successGreen)
                        .font(.system(size: 12))
                }
            }

            Divider()
                .overlay(WidgetTheme.completedGray.opacity(0.4))

            // Top 3 incomplete tasks (no section headers) — today tasks first, then must do, then nice to do
            let allIncomplete = (data.todayTasks + data.mustDoTasks + data.niceToDoTasks)
                .filter { !$0.isCompleted }
                .prefix(3)

            ForEach(Array(allIncomplete), id: \.id) { task in
                HStack(spacing: 5) {
                    Text("•")
                        .font(WidgetTheme.handwritten(13))
                        .foregroundStyle(WidgetTheme.navy.opacity(0.6))
                    Text(task.name)
                        .font(WidgetTheme.handwritten(13))
                        .foregroundStyle(WidgetTheme.navy)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Text("\(data.completedCount) of \(data.totalCount) done")
                .font(WidgetTheme.handwritten(12))
                .foregroundStyle(WidgetTheme.completedGray)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            WidgetLinedPaper()
        }
        .widgetURL(URL(string: "sown://today"))
    }
}
