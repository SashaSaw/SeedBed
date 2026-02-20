import SwiftUI

/// The type of criterion: a measurable number+unit or a time target
enum CriterionMode: String, CaseIterable {
    case measure = "Measure"
    case byTime = "By a time"
}

/// A single success criterion entry — number+unit OR a time target
struct CriterionEntry: Identifiable {
    let id = UUID()
    var mode: CriterionMode = .measure
    var value: String = ""
    var unit: String = ""
    var isCustomUnit: Bool = false
    var customUnit: String = ""
    var timeValue: Date = {
        // Default to 7:00 AM
        Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    }()
}

/// Reusable success criteria editor used in Add and Edit views.
/// Supports multiple criteria (up to 3), each being either a number+unit or a "by time".
struct CriteriaEditorView: View {
    @Binding var criteria: [CriterionEntry]
    var onChanged: (() -> Void)? = nil

    /// Predefined unit categories
    private static let unitCategories: [(category: String, units: [String])] = [
        ("Time", ["seconds", "minutes", "hours"]),
        ("Distance", ["m", "km", "miles"]),
        ("Weight", ["g", "kg", "lbs"]),
        ("Volume", ["ml", "litres"]),
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(criteria.enumerated()), id: \.element.id) { index, _ in
                criterionRow(index: index)
            }

            // Add another button (max 3)
            if criteria.count < 3 {
                addAnotherButton
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.85))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        )
    }

    // MARK: - Add Another

    private var addAnotherButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                criteria.append(CriterionEntry())
            }
            Feedback.selection()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.custom("PatrickHand-Regular", size: 12))
                Text("Add another")
                    .font(JournalTheme.Fonts.habitCriteria())
            }
            .foregroundStyle(JournalTheme.Colors.inkBlue)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .strokeBorder(JournalTheme.Colors.inkBlue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Criterion Row

    private func criterionRow(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Mode selector + remove button
            HStack {
                modePicker(index: index)
                Spacer()
                if criteria.count > 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            criteria.remove(at: index)
                            onChanged?()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.custom("PatrickHand-Regular", size: 18))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }
                }
            }

            // Input based on mode
            switch criteria[index].mode {
            case .measure:
                measureInput(index: index)
            case .byTime:
                timeInput(index: index)
            }
        }
        .padding(.bottom, index < criteria.count - 1 ? 8 : 0)
        .overlay(alignment: .bottom) {
            if index < criteria.count - 1 {
                Rectangle()
                    .fill(JournalTheme.Colors.lineLight)
                    .frame(height: 1)
                    .padding(.horizontal, -4)
            }
        }
    }

    // MARK: - Mode Picker

    private func modePicker(index: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(CriterionMode.allCases, id: \.self) { mode in
                let isSelected = criteria[index].mode == mode

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        criteria[index].mode = mode
                        onChanged?()
                    }
                    Feedback.selection()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode == .measure ? "number" : "clock")
                            .font(.custom("PatrickHand-Regular", size: 11))
                        Text(mode.rawValue)
                            .font(.custom("PatrickHand-Regular", size: 13))
                    }
                    .foregroundStyle(isSelected ? .white : JournalTheme.Colors.inkBlack)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isSelected ? JournalTheme.Colors.inkBlue : Color.clear)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isSelected ? Color.clear : JournalTheme.Colors.lineLight,
                                lineWidth: 1
                            )
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Measure Input

    private func measureInput(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // Number field
                TextField("0", text: Binding(
                    get: { criteria[index].value },
                    set: { newVal in
                        criteria[index].value = newVal
                        onChanged?()
                    }
                ))
                .font(.custom("PatrickHand-Regular", size: 17))
                .foregroundStyle(JournalTheme.Colors.inkBlack)
                .keyboardType(.decimalPad)
                .frame(width: 60)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(JournalTheme.Colors.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
                        )
                )

                // Unit display
                if !criteria[index].unit.isEmpty {
                    Text(criteria[index].isCustomUnit ? criteria[index].customUnit : criteria[index].unit)
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(JournalTheme.Colors.inkBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(JournalTheme.Colors.inkBlue.opacity(0.1))
                        )
                }

                Spacer()
            }

            // Unit picker pills
            unitPicker(index: index)
        }
    }

    // MARK: - Time Input

    private func timeInput(index: Int) -> some View {
        HStack {
            Text("Complete by")
                .font(.custom("PatrickHand-Regular", size: 15))
                .foregroundStyle(JournalTheme.Colors.inkBlack)

            DatePicker(
                "",
                selection: Binding(
                    get: { criteria[index].timeValue },
                    set: { newVal in
                        criteria[index].timeValue = newVal
                        onChanged?()
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(JournalTheme.Colors.inkBlue)

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(JournalTheme.Colors.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
                )
        )
    }

    // MARK: - Unit Picker

    private func unitPicker(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Predefined units by category
            ForEach(Self.unitCategories, id: \.category) { category in
                HStack(spacing: 6) {
                    Text(category.category)
                        .font(.custom("PatrickHand-Regular", size: 10))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                        .frame(width: 50, alignment: .trailing)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(category.units, id: \.self) { unit in
                                unitPill(unit: unit, index: index)
                            }
                        }
                    }
                }
            }

            // Custom unit row
            HStack(spacing: 6) {
                Text("Custom")
                    .font(.custom("PatrickHand-Regular", size: 10))
                    .foregroundStyle(JournalTheme.Colors.completedGray)
                    .frame(width: 50, alignment: .trailing)

                if criteria[index].isCustomUnit {
                    TextField("e.g. pages, reps", text: Binding(
                        get: { criteria[index].customUnit },
                        set: { newVal in
                            criteria[index].customUnit = newVal
                            criteria[index].unit = newVal
                            onChanged?()
                        }
                    ))
                    .font(.custom("PatrickHand-Regular", size: 13))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(JournalTheme.Colors.inkBlue.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .strokeBorder(JournalTheme.Colors.inkBlue.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .frame(maxWidth: 150)
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            criteria[index].isCustomUnit = true
                            criteria[index].unit = ""
                            criteria[index].customUnit = ""
                        }
                        Feedback.selection()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.custom("PatrickHand-Regular", size: 10))
                            Text("Custom")
                                .font(.custom("PatrickHand-Regular", size: 13))
                        }
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color.clear)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func unitPill(unit: String, index: Int) -> some View {
        let isSelected = !criteria[index].isCustomUnit && criteria[index].unit == unit

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                criteria[index].unit = unit
                criteria[index].isCustomUnit = false
                criteria[index].customUnit = ""
                onChanged?()
            }
            Feedback.selection()
        } label: {
            Text(unit)
                .font(.custom("PatrickHand-Regular", size: 13))
                .foregroundStyle(isSelected ? .white : JournalTheme.Colors.inkBlack)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? JournalTheme.Colors.inkBlue : Color.clear)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? Color.clear : JournalTheme.Colors.lineLight,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Build Criteria String

    /// Builds the comma-separated criteria string for storage
    static func buildCriteriaString(from criteria: [CriterionEntry]) -> String {
        let validCriteria = criteria.compactMap { entry -> String? in
            switch entry.mode {
            case .measure:
                let value = entry.value.trimmingCharacters(in: .whitespaces)
                guard !value.isEmpty else { return nil }

                let unitStr: String
                if entry.isCustomUnit {
                    let custom = entry.customUnit.trimmingCharacters(in: .whitespaces)
                    guard !custom.isEmpty else { return nil }
                    unitStr = custom
                } else {
                    guard !entry.unit.isEmpty else { return nil }
                    unitStr = entry.unit
                }

                return "\(value) \(unitStr)"

            case .byTime:
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mma"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                let timeStr = formatter.string(from: entry.timeValue).lowercased()
                return "by \(timeStr)"
            }
        }

        return validCriteria.joined(separator: ", ")
    }

    /// Parses an existing criteria string back into CriterionEntry array
    static func parseCriteriaString(_ raw: String?) -> [CriterionEntry] {
        guard let raw = raw, !raw.isEmpty else { return [CriterionEntry()] }

        let timeKeywords = ["by", "before", "at", "after", "until"]
        let parts = raw.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        let entries: [CriterionEntry] = parts.compactMap { part in
            guard !part.isEmpty else { return nil }
            let lower = part.lowercased()

            // Check if time-based
            if timeKeywords.contains(where: { lower.hasPrefix($0 + " ") }) {
                var entry = CriterionEntry()
                entry.mode = .byTime
                entry.timeValue = parseTime(from: part, keywords: timeKeywords)
                return entry
            }

            // Parse as number + unit (handles ranges like "2-3L" or "2-3 litres")
            var numberPart = ""
            var unitPart = ""

            // Extract trailing unit (letters only) from the end
            var chars = Array(part)
            var unitChars: [Character] = []
            while let last = chars.last, last.isLetter {
                unitChars.insert(chars.removeLast(), at: 0)
            }
            unitPart = String(unitChars).trimmingCharacters(in: .whitespaces)

            // The rest is the number/range part
            numberPart = String(chars).trimmingCharacters(in: .whitespaces)

            guard !numberPart.isEmpty else { return nil }

            var entry = CriterionEntry()
            entry.mode = .measure
            entry.value = numberPart

            // Check if unit matches a predefined one (including common abbreviations)
            let unitAbbreviations: [String: String] = [
                "l": "litres", "L": "litres", "ltr": "litres", "litre": "litres",
                "ml": "ml", "ML": "ml",
                "kg": "kg", "KG": "kg", "kilo": "kg", "kilos": "kg",
                "g": "g", "gram": "g", "grams": "g",
                "lb": "lbs", "pound": "lbs", "pounds": "lbs",
                "m": "m", "meter": "m", "meters": "m", "metre": "m", "metres": "m",
                "km": "km", "kilometer": "km", "kilometers": "km",
                "mi": "miles", "mile": "miles",
                "sec": "seconds", "secs": "seconds", "second": "seconds",
                "min": "minutes", "mins": "minutes", "minute": "minutes",
                "hr": "hours", "hrs": "hours", "hour": "hours",
            ]

            let allPredefined = unitCategories.flatMap(\.units)
            let normalizedUnit = unitAbbreviations[unitPart] ?? unitAbbreviations[unitPart.lowercased()]

            if let normalized = normalizedUnit, allPredefined.contains(normalized) {
                entry.unit = normalized
            } else if allPredefined.contains(where: { $0.lowercased() == unitPart.lowercased() }) {
                entry.unit = allPredefined.first(where: { $0.lowercased() == unitPart.lowercased() }) ?? unitPart
            } else if !unitPart.isEmpty {
                entry.isCustomUnit = true
                entry.customUnit = unitPart
                entry.unit = unitPart
            }

            return entry
        }

        return entries.isEmpty ? [CriterionEntry()] : entries
    }

    /// Check if criteria has at least one valid entry
    static func hasValidCriteria(_ criteria: [CriterionEntry]) -> Bool {
        criteria.contains { entry in
            switch entry.mode {
            case .measure:
                let hasValue = !entry.value.trimmingCharacters(in: .whitespaces).isEmpty
                let hasUnit: Bool
                if entry.isCustomUnit {
                    hasUnit = !entry.customUnit.trimmingCharacters(in: .whitespaces).isEmpty
                } else {
                    hasUnit = !entry.unit.isEmpty
                }
                return hasValue && hasUnit
            case .byTime:
                return true // Time always has a value
            }
        }
    }

    // MARK: - Time Parsing Helper

    private static func parseTime(from text: String, keywords: [String]) -> Date {
        var timeStr = text
        for keyword in keywords {
            if timeStr.lowercased().hasPrefix(keyword + " ") {
                timeStr = String(timeStr.dropFirst(keyword.count + 1)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        let calendar = Calendar.current
        let formats = ["h:mma", "h:mm a", "ha", "h a", "HH:mm", "H:mm"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in formats {
            formatter.dateFormat = format
            if let parsed = formatter.date(from: timeStr) {
                let comps = calendar.dateComponents([.hour, .minute], from: parsed)
                return calendar.date(from: DateComponents(
                    year: calendar.component(.year, from: Date()),
                    month: calendar.component(.month, from: Date()),
                    day: calendar.component(.day, from: Date()),
                    hour: comps.hour,
                    minute: comps.minute
                )) ?? Date()
            }
        }

        return calendar.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    }
}
