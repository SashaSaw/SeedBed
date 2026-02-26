import SwiftUI

/// Screen 3: Esteem + Self-Actualisation (Maslow Level 4+5)
struct FulfilmentScreen: View {
    @Bindable var data: OnboardingData
    let onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Prompt
                VStack(alignment: .leading, spacing: 10) {
                    Text("Now the good stuff.\nWhat would you like to start doing?")
                        .font(.custom("PatrickHand-Regular", size: 24))
                        .foregroundStyle(JournalTheme.Colors.navy)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    (Text("These will be your ")
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                    + Text("nice to dos")
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(JournalTheme.Colors.navy)
                    + Text(". Hobbies, interests, things you want to do more of \u{2014} they don\u{2019}t have to be daily, just things you\u{2019}d like in your routine.")
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(JournalTheme.Colors.completedGray))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Suggestion pills
                SuggestionPillGrid(
                    suggestions: HabitSuggestion.fulfilment,
                    selectedNames: $data.selectedFulfilment,
                    customPills: $data.customFulfilment,
                    customPillEmojis: $data.customPillEmojis
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Add custom pill
                AddCustomPillField(
                    placeholder: "e.g. 🎸 Guitar, Yoga, Learn Spanish...",
                    selectedNames: $data.selectedFulfilment,
                    customPills: $data.customFulfilment,
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
                    hasSelections: !data.selectedFulfilment.isEmpty,
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
