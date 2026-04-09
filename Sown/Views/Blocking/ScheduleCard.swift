import SwiftUI
import Combine

/// Schedule card with inline per-day editing — day toggles, expandable time pickers, apply-to-all.
/// Edits are buffered in draft state and only applied when the user taps Save.
struct ScheduleCard: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var blockSettings = BlockSettings.shared
    @State private var expandedDay: Int? = nil
    @State private var refreshTick = false

    // MARK: - Draft State

    @State private var draftEntries: [BlockScheduleEntry] = []
    @State private var hasUnsavedChanges = false

    private let dayAbbreviations = ["S", "M", "T", "W", "T", "F", "S"]
    private let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    /// Whether a specific day is locked (currently in an active blocking window)
    private func isDayLocked(_ day: Int) -> Bool {
        guard blockSettings.isEnabled else { return false }
        let currentWeekday = Calendar.current.component(.weekday, from: Date())
        return day == currentWeekday && blockSettings.isCurrentlyActive
    }

    /// Days that have a draft entry
    private var draftScheduledDays: Set<Int> {
        Set(draftEntries.map(\.dayOfWeek))
    }

    /// Get draft entry for a day
    private func draftEntry(for dayOfWeek: Int) -> BlockScheduleEntry? {
        draftEntries.first { $0.dayOfWeek == dayOfWeek }
    }

    /// Update or create a draft entry
    private func updateDraftEntry(dayOfWeek: Int, startMinutes: Int, endMinutes: Int) {
        if let index = draftEntries.firstIndex(where: { $0.dayOfWeek == dayOfWeek }) {
            draftEntries[index] = BlockScheduleEntry(
                id: draftEntries[index].id,
                dayOfWeek: dayOfWeek,
                startMinutes: startMinutes,
                endMinutes: endMinutes
            )
        } else {
            draftEntries.append(BlockScheduleEntry(
                dayOfWeek: dayOfWeek,
                startMinutes: startMinutes,
                endMinutes: endMinutes
            ))
        }
        hasUnsavedChanges = true
    }

    /// Remove a draft entry
    private func removeDraftEntry(dayOfWeek: Int) {
        draftEntries.removeAll { $0.dayOfWeek == dayOfWeek }
        hasUnsavedChanges = true
    }

    var body: some View {
        let _ = refreshTick
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "clock")
                    .font(.custom("PatrickHand-Regular", size: 15))
                    .foregroundStyle(JournalTheme.Colors.amber)

                Text("Block Schedule")
                    .font(.custom("PatrickHand-Regular", size: 15))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                if hasUnsavedChanges {
                    Text("(unsaved)")
                        .font(.custom("PatrickHand-Regular", size: 12))
                        .foregroundStyle(JournalTheme.Colors.amber)
                }
            }

            // Day toggle circles
            HStack(spacing: 6) {
                ForEach(Array(zip(dayAbbreviations, 1...7)), id: \.1) { label, day in
                    let isActive = draftScheduledDays.contains(day)
                    let locked = isDayLocked(day)
                    Button {
                        Feedback.selection()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if isActive {
                                removeDraftEntry(dayOfWeek: day)
                                if expandedDay == day { expandedDay = nil }
                            } else {
                                let refEntry = draftEntries.first
                                updateDraftEntry(
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
                                    .fill(locked ? JournalTheme.Colors.negativeRedDark : isActive ? JournalTheme.Colors.amber : JournalTheme.Colors.paper)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(isActive ? Color.clear : JournalTheme.Colors.lineMedium, lineWidth: 1)
                                    )
                            )
                    }
                    .disabled(locked)
                }
            }

            // Apply to all button — locked during active blocking
            if draftEntries.count > 1 {
                let isBlockingActive = blockSettings.isEnabled && blockSettings.isCurrentlyActive
                Button {
                    Feedback.buttonPress()
                    guard let ref = draftEntries.first else { return }
                    for day in draftScheduledDays where !isDayLocked(day) {
                        updateDraftEntry(dayOfWeek: day, startMinutes: ref.startMinutes, endMinutes: ref.endMinutes)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isBlockingActive ? "lock.fill" : "arrow.triangle.2.circlepath")
                            .font(.system(size: 12))
                        Text("Apply first day's times to all")
                            .font(.custom("PatrickHand-Regular", size: 13))
                    }
                    .foregroundStyle(isBlockingActive ? JournalTheme.Colors.negativeRedDark : JournalTheme.Colors.inkBlue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isBlockingActive ? JournalTheme.Colors.negativeRedDark.opacity(0.08) : JournalTheme.Colors.inkBlue.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isBlockingActive)
            }

            // Per-day editors
            ForEach(1...7, id: \.self) { day in
                dayEditorRow(dayOfWeek: day)
            }

            // Save / Discard buttons
            if hasUnsavedChanges {
                HStack(spacing: 12) {
                    Button {
                        Feedback.buttonPress()
                        draftEntries = blockSettings.scheduleEntries
                        hasUnsavedChanges = false
                        expandedDay = nil
                    } label: {
                        Text("Discard")
                            .font(.custom("PatrickHand-Regular", size: 14))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(JournalTheme.Colors.lineMedium, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Feedback.buttonPress()
                        // Commit draft to BlockSettings
                        blockSettings.scheduleEntries = draftEntries
                        if blockSettings.isEnabled {
                            ScreenTimeManager.shared.updateBlocking()
                        }
                        hasUnsavedChanges = false
                        expandedDay = nil
                    } label: {
                        Text("Save Schedule")
                            .font(.custom("PatrickHand-Regular", size: 14))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(JournalTheme.Colors.amber)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JournalTheme.Colors.paperLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(hasUnsavedChanges ? JournalTheme.Colors.amber.opacity(0.5) : JournalTheme.Colors.lineMedium, lineWidth: 1)
                )
        )
        .onAppear {
            draftEntries = blockSettings.scheduleEntries
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            refreshTick.toggle()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshTick.toggle()
                // Sync draft from settings if no unsaved changes (external change)
                if !hasUnsavedChanges {
                    draftEntries = blockSettings.scheduleEntries
                }
            }
        }
    }

    // MARK: - Per-Day Editor Row

    private func dayEditorRow(dayOfWeek: Int) -> some View {
        let entry = draftEntry(for: dayOfWeek)
        let isExpanded = expandedDay == dayOfWeek
        let hasEntry = entry != nil
        let locked = isDayLocked(dayOfWeek)

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
                        .foregroundStyle(locked ? JournalTheme.Colors.negativeRedDark : hasEntry ? JournalTheme.Colors.inkBlack : JournalTheme.Colors.completedGray)

                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(JournalTheme.Colors.negativeRedDark)
                    }

                    Spacer()

                    if let entry {
                        Text("\(blockSettings.formatMinutes(entry.startMinutes)) – \(blockSettings.formatMinutes(entry.endMinutes))")
                            .font(.custom("PatrickHand-Regular", size: 13))
                            .foregroundStyle(locked ? JournalTheme.Colors.negativeRedDark.opacity(0.7) : JournalTheme.Colors.completedGray)
                    } else {
                        Text("Off")
                            .font(.custom("PatrickHand-Regular", size: 13))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }

                    if hasEntry && !locked {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            .disabled(!hasEntry || locked)

            // Expanded time pickers
            if isExpanded, let entry {
                VStack(spacing: 10) {
                    Divider()

                    timePicker(label: "Start", minutes: entry.startMinutes) { newMinutes in
                        updateDraftEntry(dayOfWeek: dayOfWeek, startMinutes: newMinutes, endMinutes: entry.endMinutes)
                    }

                    timePicker(label: "End", minutes: entry.endMinutes) { newMinutes in
                        updateDraftEntry(dayOfWeek: dayOfWeek, startMinutes: entry.startMinutes, endMinutes: newMinutes)
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
