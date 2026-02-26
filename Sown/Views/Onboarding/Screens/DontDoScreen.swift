import SwiftUI

/// Screen 4: Things to quit / avoid (negative habits)
struct DontDoScreen: View {
    @Bindable var data: OnboardingData
    let onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Prompt
                OnboardingPromptView(
                    question: "Anything you're trying to quit?",
                    subtitle: "Bad habits you want to break or things you want to avoid."
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Suggestion pills
                SuggestionPillGrid(
                    suggestions: HabitSuggestion.dontDos,
                    selectedNames: $data.selectedDontDos,
                    customPills: $data.customDontDos
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Add custom pill
                AddCustomPillField(
                    placeholder: "e.g. No energy drinks, No nail biting...",
                    selectedNames: $data.selectedDontDos,
                    customPills: $data.customDontDos
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                OnboardingContinueButton(
                    hasSelections: !data.selectedDontDos.isEmpty,
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
