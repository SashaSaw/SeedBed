import SwiftUI

/// Schedule card with inline per-day editing — day toggles, expandable time pickers, apply-to-all
struct ScheduleCard: View {
    @State private var blockSettings = BlockSettings.shared
    @State private var expandedDay: Int? = nil

    private let dayAbbreviations = ["S", "M", "T", "W", "T", "F", "S"]
    private let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "clock")
                    .font(.custom("PatrickHand-Regular", size: 15))
                    .foregroundStyle(JournalTheme.Colors.amber)

                Text("Block Schedule")
                    .font(.custom("PatrickHand-Regular", size: 15))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
            }

            // Day toggle circles
            HStack(spacing: 6) {
                ForEach(Array(zip(dayAbbreviations, 1...7)), id: \.1) { label, day in
                    let isActive = blockSettings.scheduledDays.contains(day)
                    Button {
                        Feedback.selection()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if isActive {
                                blockSettings.removeEntry(dayOfWeek: day)
                                if expandedDay == day { expandedDay = nil }
                            } else {
                                let refEntry = blockSettings.scheduleEntries.first
                                blockSettings.updateEntry(
                                    dayOfWeek: day,
                                    startMinutes: refEntry?.startMinutes ?? 9 * 60,
                                    endMinutes: refEntry?.endMinutes ?? 21 * 60
                                )
                            }
                        }
                    } label: {
                        Text(label)
                            .font(.custom("PatrickHand-Regular", size: 13))
                            .foregroundStyle(isActive ? .white : JournalTheme.Colors.completedGray)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(isActive ? JournalTheme.Colors.amber : JournalTheme.Colors.paper)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(isActive ? Color.clear : JournalTheme.Colors.lineMedium, lineWidth: 1)
                                    )
                            )
                    }
                }
            }

            // Apply to all button
            if blockSettings.scheduleEntries.count > 1 {
                Button {
                    Feedback.buttonPress()
                    guard let ref = blockSettings.scheduleEntries.first else { return }
                    for day in blockSettings.scheduledDays {
                        blockSettings.updateEntry(dayOfWeek: day, startMinutes: ref.startMinutes, endMinutes: ref.endMinutes)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12))
                        Text("Apply first day's times to all")
                            .font(.custom("PatrickHand-Regular", size: 13))
                    }
                    .foregroundStyle(JournalTheme.Colors.inkBlue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(JournalTheme.Colors.inkBlue.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }

            // Per-day editors
            ForEach(1...7, id: \.self) { day in
                dayEditorRow(dayOfWeek: day)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JournalTheme.Colors.paperLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(JournalTheme.Colors.lineMedium, lineWidth: 1)
                )
        )
        .onChange(of: blockSettings.scheduleEntries) { _, _ in
            if blockSettings.isEnabled {
                ScreenTimeManager.shared.updateBlocking()
            }
        }
    }

    // MARK: - Per-Day Editor Row

    private func dayEditorRow(dayOfWeek: Int) -> some View {
        let entry = blockSettings.entry(for: dayOfWeek)
        let isExpanded = expandedDay == dayOfWeek
        let hasEntry = entry != nil

        return VStack(spacing: 0) {
            // Day header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedDay = nil
                    } else if hasEntry {
                        expandedDay = dayOfWeek
                    }
                }
            } label: {
                HStack {
                    Text(dayNames[dayOfWeek - 1])
                        .font(.custom("PatrickHand-Regular", size: 15))
                        .foregroundStyle(hasEntry ? JournalTheme.Colors.inkBlack : JournalTheme.Colors.completedGray)

                    Spacer()

                    if let entry {
                        Text("\(blockSettings.formatMinutes(entry.startMinutes)) – \(blockSettings.formatMinutes(entry.endMinutes))")
                            .font(.custom("PatrickHand-Regular", size: 13))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    } else {
                        Text("Off")
                            .font(.custom("PatrickHand-Regular", size: 13))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }

                    if hasEntry {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            .disabled(!hasEntry)

            // Expanded time pickers
            if isExpanded, let entry {
                VStack(spacing: 10) {
                    Divider()

                    timePicker(label: "Start", minutes: entry.startMinutes) { newMinutes in
                        blockSettings.updateEntry(dayOfWeek: dayOfWeek, startMinutes: newMinutes, endMinutes: entry.endMinutes)
                    }

                    timePicker(label: "End", minutes: entry.endMinutes) { newMinutes in
                        blockSettings.updateEntry(dayOfWeek: dayOfWeek, startMinutes: entry.startMinutes, endMinutes: newMinutes)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(JournalTheme.Colors.paper)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(JournalTheme.Colors.lineMedium, lineWidth: 1)
                )
        )
    }

    // MARK: - Time Picker

    private func timePicker(label: String, minutes: Int, onChange: @escaping (Int) -> Void) -> some View {
        let date = Binding<Date>(
            get: {
                Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                let newMinutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
                onChange(newMinutes)
            }
        )

        return HStack {
            Text(label)
                .font(.custom("PatrickHand-Regular", size: 14))
                .foregroundStyle(JournalTheme.Colors.inkBlack)
                .frame(width: 40, alignment: .leading)

            DatePicker("", selection: date, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .environment(\.colorScheme, .light)
                .fixedSize()
        }
    }
}
