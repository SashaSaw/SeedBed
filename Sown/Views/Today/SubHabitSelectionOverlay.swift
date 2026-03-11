import SwiftUI

/// Overlay shown when swiping a group header to pick which sub-habit was completed.
struct SubHabitSelectionOverlay: View {
    let group: HabitGroup
    let habits: [Habit]  // uncompleted sub-habits
    let onSelect: (Habit) -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background — tap to dismiss
                Color.white.opacity(0.7)
                    .onTapGesture { onDismiss() }

                // Content card
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 6) {
                        Text(group.name)
                            .font(.custom("PatrickHand-Regular", size: 24))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)

                        Text("Which one did you do?")
                            .font(.custom("PatrickHand-Regular", size: 16))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }

                    // Sub-habit options
                    VStack(spacing: 0) {
                        ForEach(habits) { habit in
                            Button {
                                onSelect(habit)
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(JournalTheme.Colors.inkBlack)
                                        .frame(width: 6, height: 6)

                                    Text(habit.name)
                                        .font(.custom("PatrickHand-Regular", size: 18))
                                        .foregroundStyle(JournalTheme.Colors.inkBlack)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(JournalTheme.Colors.completedGray)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if habit.id != habits.last?.id {
                                Divider()
                                    .foregroundStyle(JournalTheme.Colors.lineLight)
                            }
                        }
                    }

                    // Cancel button
                    Button {
                        onDismiss()
                    } label: {
                        Text("Cancel")
                            .font(.custom("PatrickHand-Regular", size: 16))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(JournalTheme.Colors.lineLight, lineWidth: 1)
                            )
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                )
                .padding(.horizontal, 32)
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}
