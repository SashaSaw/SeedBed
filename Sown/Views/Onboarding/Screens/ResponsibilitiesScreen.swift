import SwiftUI

/// Screen 3: Safety + Belonging (Maslow Level 2+3)
struct ResponsibilitiesScreen: View {
    @Bindable var data: OnboardingData
    let onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Prompt
                OnboardingPromptView(
                    question: "What keeps your life on track?",
                    subtitle: "The things that nag at you when they\u{2019}re undone."
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Suggestion pills
                SuggestionPillGrid(
                    suggestions: HabitSuggestion.responsibilities,
                    selectedNames: $data.selectedResponsibilities,
                    customPills: $data.customResponsibilities,
                    customPillEmojis: $data.customPillEmojis
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Add custom pill
                AddCustomPillField(
                    placeholder: "e.g. 🪴 Water plants, Check emails...",
                    selectedNames: $data.selectedResponsibilities,
                    customPills: $data.customResponsibilities,
                    customPillEmojis: $data.customPillEmojis
                )
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
                    hasSelections: !data.selectedResponsibilities.isEmpty,
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
