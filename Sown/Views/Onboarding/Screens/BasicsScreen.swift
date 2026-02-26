import SwiftUI

/// Screen 1: Must-do habits (basics + responsibilities merged)
struct BasicsScreen: View {
    @Bindable var data: OnboardingData
    let onContinue: () -> Void

    @State private var appeared = false

    private var hasSelections: Bool {
        !data.selectedBasics.isEmpty || !data.selectedResponsibilities.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Prompt
                VStack(alignment: .leading, spacing: 10) {
                    (Text("What should you be doing ")
                        .font(.custom("PatrickHand-Regular", size: 24))
                    + Text("every day")
                        .font(.custom("PatrickHand-Regular", size: 24))
                        .bold()
                        .underline()
                    + Text("?")
                        .font(.custom("PatrickHand-Regular", size: 24)))
                        .foregroundStyle(JournalTheme.Colors.navy)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    (Text("These will become your ")
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                    + Text("must dos")
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(JournalTheme.Colors.amber)
                    + Text(". They are non-negotiable and you should aim to do these for a good productive day.")
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(JournalTheme.Colors.completedGray))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Basics suggestion pills
                SuggestionPillGrid(
                    suggestions: HabitSuggestion.basics,
                    selectedNames: $data.selectedBasics,
                    customPills: $data.customBasics,
                    customPillEmojis: $data.customPillEmojis
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Responsibilities suggestion pills
                SuggestionPillGrid(
                    suggestions: HabitSuggestion.responsibilities,
                    selectedNames: $data.selectedResponsibilities,
                    customPills: $data.customResponsibilities,
                    customPillEmojis: $data.customPillEmojis
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Add custom pill (shared across both)
                AddCustomPillField(
                    placeholder: "e.g. 🧘 Stretch, Skincare routine...",
                    selectedNames: $data.selectedBasics,
                    customPills: $data.customBasics,
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
                    hasSelections: hasSelections,
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
