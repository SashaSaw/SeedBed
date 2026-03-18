import SwiftUI

/// Reusable toggle pill grid for onboarding suggestion selection
struct SuggestionPillGrid: View {
    let suggestions: [HabitSuggestion]
    @Binding var selectedNames: Set<String>
    @Binding var customPills: [String]
    @Binding var customPillEmojis: [String: String]

    var body: some View {
        FlowLayout(spacing: 10) {
            // Template suggestions
            ForEach(suggestions, id: \.name) { suggestion in
                SuggestionPill(
                    emoji: suggestion.emoji,
                    name: suggestion.name,
                    isSelected: selectedNames.contains(suggestion.name),
                    isCustom: false,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedNames.contains(suggestion.name) {
                                selectedNames.remove(suggestion.name)
                            } else {
                                selectedNames.insert(suggestion.name)
                            }
                        }
                        Feedback.selection()
                    }
                )
            }

            // User-added custom pills (always selected, tap to remove)
            ForEach(customPills, id: \.self) { name in
                SuggestionPill(
                    emoji: customPillEmojis[name] ?? "\u{2728}",
                    name: name,
                    isSelected: true,
                    isCustom: true,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            customPills.removeAll { $0 == name }
                            selectedNames.remove(name)
                            customPillEmojis.removeValue(forKey: name)
                        }
                        Feedback.selection()
                    }
                )
            }
        }
    }
}

// MARK: - Add Custom Pill Field

struct AddCustomPillField: View {
    let placeholder: String
    @Binding var selectedNames: Set<String>
    @Binding var customPills: [String]
    @Binding var customPillEmojis: [String: String]

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Something else? Add an emoji too!")
                .font(.custom("PatrickHand-Regular", size: 13))
                .foregroundStyle(JournalTheme.Colors.completedGray)

            HStack(spacing: 10) {
                TextField("", text: $text, prompt: Text(placeholder)
                    .font(.custom("PatrickHand-Regular", size: 15))
                    .foregroundStyle(JournalTheme.Colors.completedGray))
                    .font(.custom("PatrickHand-Regular", size: 15))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                    .focused($isFocused)
                    .onSubmit { addPill() }

                Button(action: addPill) {
                    Image(systemName: "plus.circle.fill")
                        .font(.custom("PatrickHand-Regular", size: 24))
                        .foregroundStyle(trimmedText.isEmpty ? JournalTheme.Colors.lineLight : JournalTheme.Colors.navy)
                }
                .disabled(trimmedText.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(JournalTheme.Colors.paperLight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isFocused ? JournalTheme.Colors.navy.opacity(0.4) : JournalTheme.Colors.lineLight, lineWidth: 1)
            )
        }
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespaces)
    }

    private func addPill() {
        guard !trimmedText.isEmpty else { return }

        let (emoji, name) = parseLeadingEmoji(from: trimmedText)

        guard !name.isEmpty else {
            text = ""
            return
        }

        // Don't add duplicates
        guard !selectedNames.contains(name) && !customPills.contains(name) else {
            text = ""
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            if let emoji {
                customPillEmojis[name] = emoji
            }
            customPills.append(name)
            selectedNames.insert(name)
        }
        text = ""
        Feedback.selection()
    }

    /// Extracts a leading emoji from the input, returning (emoji, remainingName).
    /// e.g. "🧘 Yoga" → ("🧘", "Yoga"), "Stretch" → (nil, "Stretch")
    private func parseLeadingEmoji(from input: String) -> (String?, String) {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard let firstChar = trimmed.first else { return (nil, trimmed) }

        let scalars = firstChar.unicodeScalars
        guard let firstScalar = scalars.first else { return (nil, trimmed) }

        // Multi-scalar characters (ZWJ sequences, skin tones) are always emojis.
        // Single-scalar emojis must pass the isEmoji check and not be ASCII (digits, #, *).
        let isEmoji = scalars.count > 1
            ? firstScalar.properties.isEmoji
            : firstScalar.properties.isEmoji && firstScalar.value > 0xFF

        if isEmoji {
            let remaining = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            return remaining.isEmpty ? (nil, String(firstChar)) : (String(firstChar), remaining)
        }
        return (nil, trimmed)
    }
}

// MARK: - Individual Pill

private struct SuggestionPill: View {
    let emoji: String
    let name: String
    let isSelected: Bool
    let isCustom: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.custom("PatrickHand-Regular", size: 15))
                Text(name)
                    .font(.custom("PatrickHand-Regular", size: 14))
                    .foregroundStyle(isSelected ? Color.white : JournalTheme.Colors.inkBlack)

                // Show X on custom pills to hint they can be removed
                if isCustom {
                    Image(systemName: "xmark")
                        .font(.custom("PatrickHand-Regular", size: 10))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(
                    isSelected ? JournalTheme.Colors.navy : Color.white.opacity(0.85)
                )
            )
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.clear : JournalTheme.Colors.lineLight,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }
}
