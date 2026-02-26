import SwiftUI

/// Screen 4: Wake/sleep/work schedule
struct ScheduleScreen: View {
    @Bindable var data: OnboardingData
    let onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Prompt
                OnboardingPromptView(
                    question: "When does your day start and end?",
                    subtitle: "This helps us organise your habits around your schedule."
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Time pickers
                VStack(spacing: 16) {
                    timeRow(label: "I wake up around", emoji: "\u{1F305}", time: $data.wakeUpTime)
                    timeRow(label: "I go to bed around", emoji: "\u{1F319}", time: $data.bedTime)

                    // Work hours toggle
                    VStack(spacing: 12) {
                        HStack {
                            Toggle(isOn: $data.hasSetWorkHours) {
                                Text("I have set work hours")
                                    .font(.custom("PatrickHand-Regular", size: 15))
                                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                            }
                            .tint(JournalTheme.Colors.navy)
                        }

                        if data.hasSetWorkHours {
                            timeRow(label: "I start work at", emoji: "\u{1F4BC}", time: $data.workStartTime)
                            timeRow(label: "I finish work at", emoji: "\u{1F3E0}", time: $data.workEndTime)
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: data.hasSetWorkHours)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

                // Smart reminders card
                SmartReminderSettingsCard()
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.custom("PatrickHand-Regular", size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(JournalTheme.Colors.navy)
                        )
                }
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
        .onChange(of: data.wakeUpTime) { _, newValue in
            UserSchedule.shared.updateFromOnboarding(wakeTime: newValue, bedTime: data.bedTime)
        }
        .onChange(of: data.bedTime) { _, newValue in
            UserSchedule.shared.updateFromOnboarding(wakeTime: data.wakeUpTime, bedTime: newValue)
        }
    }

    // MARK: - Time Row

    private func timeRow(label: String, emoji: String, time: Binding<Date>) -> some View {
        HStack {
            Text(emoji)
                .font(.custom("PatrickHand-Regular", size: 20))

            Text(label)
                .font(.custom("PatrickHand-Regular", size: 15))
                .foregroundStyle(JournalTheme.Colors.inkBlack)

            Spacer()

            DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(JournalTheme.Colors.navy)
                .environment(\.colorScheme, .light)
                .fixedSize()
        }
        .padding(14)
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
