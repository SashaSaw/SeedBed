import SwiftUI

/// Onboarding screen for one-off today tasks
struct TodayTasksScreen: View {
    @Bindable var data: OnboardingData
    let onContinue: () -> Void

    @State private var appeared = false
    @State private var hiddenSuggestions: Set<String> = []

    private let taskSuggestions = [
        "Doctor appointment", "Buy groceries", "Pay bills",
        "Reply to emails", "Call plumber", "Return package",
        "Clean the house", "Haircut", "Buy a gift"
    ]

    /// Suggestions not yet added as tasks
    private var visibleSuggestions: [String] {
        taskSuggestions.filter { !hiddenSuggestions.contains($0) && !data.todayTasks.contains($0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Prompt
                VStack(alignment: .leading, spacing: 10) {
                    Text("Anything you need to get done today?")
                        .font(.custom("PatrickHand-Regular", size: 24))
                        .foregroundStyle(JournalTheme.Colors.navy)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    (Text("These are your basic ")
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                    + Text("to dos")
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(JournalTheme.Colors.teal)
                    + Text(". They disappear once done.")
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(JournalTheme.Colors.completedGray))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Task suggestion pills
                if !visibleSuggestions.isEmpty {
                    FlowLayout(spacing: 10) {
                        ForEach(visibleSuggestions, id: \.self) { suggestion in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    data.todayTasks.append(suggestion)
                                    data.selectedTasks.insert(suggestion)
                                    hiddenSuggestions.insert(suggestion)
                                }
                                Feedback.selection()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(JournalTheme.Colors.teal)
                                    Text(suggestion)
                                        .font(.custom("PatrickHand-Regular", size: 14))
                                        .foregroundStyle(JournalTheme.Colors.inkBlack)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .strokeBorder(JournalTheme.Colors.teal.opacity(0.5), lineWidth: 1)
                                        .background(Capsule().fill(JournalTheme.Colors.teal.opacity(0.08)))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
                }

                // Task pills (added tasks)
                VStack(alignment: .leading, spacing: 12) {
                    if !data.todayTasks.isEmpty {
                        FlowLayout(spacing: 10) {
                            ForEach(data.todayTasks, id: \.self) { task in
                                OnboardingTaskPill(name: task) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        data.todayTasks.removeAll { $0 == task }
                                        data.selectedTasks.remove(task)
                                        // Re-show the suggestion if it was from the list
                                        hiddenSuggestions.remove(task)
                                    }
                                    Feedback.selection()
                                }
                            }
                        }
                    }

                    // Add task field
                    AddCustomPillField(
                        placeholder: "e.g. 📌 Pay electricity bill, Book dentist...",
                        selectedNames: $data.selectedTasks,
                        customPills: $data.todayTasks,
                        customPillEmojis: $data.customPillEmojis
                    )
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                OnboardingContinueButton(
                    hasSelections: !data.todayTasks.isEmpty,
                    action: onContinue
                )
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
            .background(
                LinearGradient(
                    colors: [JournalTheme.Colors.paper.opacity(0), JournalTheme.Colors.paper],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
                .allowsHitTesting(false)
            )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                appeared = true
            }
        }
    }
}

// MARK: - Task Pill (teal accent, X to remove)

struct OnboardingTaskPill: View {
    let name: String
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 6) {
                Text("\u{1F4CC}")
                    .font(.custom("PatrickHand-Regular", size: 15))
                Text(name)
                    .font(.custom("PatrickHand-Regular", size: 14))
                    .foregroundStyle(Color.white)
                Image(systemName: "xmark")
                    .font(.custom("PatrickHand-Regular", size: 10))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(JournalTheme.Colors.teal)
            )
        }
        .buttonStyle(.plain)
    }
}
