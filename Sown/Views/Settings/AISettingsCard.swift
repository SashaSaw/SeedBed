import SwiftUI

/// Settings card for managing the Anthropic API key
struct AISettingsCard: View {
    @State private var apiKeyInput = ""
    @State private var hasKey = false
    @State private var showSavedConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.custom("PatrickHand-Regular", size: 18))
                    .foregroundStyle(JournalTheme.Colors.teal)

                Text("AI Assistant")
                    .font(.custom("PatrickHand-Regular", size: 17))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                Spacer()

                // Status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(hasKey ? JournalTheme.Colors.successGreen : JournalTheme.Colors.completedGray)
                        .frame(width: 8, height: 8)

                    Text(hasKey ? "Connected" : "No key set")
                        .font(.custom("PatrickHand-Regular", size: 13))
                        .foregroundStyle(hasKey ? JournalTheme.Colors.successGreen : JournalTheme.Colors.completedGray)
                }
            }

            // Key input
            SecureField("sk-ant-...", text: $apiKeyInput)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(JournalTheme.Colors.inkBlack)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
                )
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            // Buttons
            HStack(spacing: 12) {
                if hasKey {
                    Button {
                        Feedback.buttonPress()
                        APIKeyStorage.delete()
                        apiKeyInput = ""
                        hasKey = false
                    } label: {
                        Text("Remove")
                            .font(.custom("PatrickHand-Regular", size: 14))
                            .foregroundStyle(JournalTheme.Colors.coral)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(JournalTheme.Colors.coral, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    Feedback.buttonPress()
                    let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    if APIKeyStorage.save(apiKey: trimmed) {
                        hasKey = true
                        showSavedConfirmation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showSavedConfirmation = false
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if showSavedConfirmation {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12))
                        }
                        Text(showSavedConfirmation ? "Saved" : "Save Key")
                            .font(.custom("PatrickHand-Regular", size: 14))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(showSavedConfirmation ? JournalTheme.Colors.successGreen : JournalTheme.Colors.teal)
                    )
                }
                .buttonStyle(.plain)
                .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }

            // Helper text
            Text("Get a key at console.anthropic.com — powers Smart Add (AI habit creation).")
                .font(.custom("PatrickHand-Regular", size: 12))
                .foregroundStyle(JournalTheme.Colors.completedGray)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JournalTheme.Colors.paperLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
        )
        .onAppear {
            hasKey = APIKeyStorage.load() != nil
        }
    }
}
