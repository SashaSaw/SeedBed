import SwiftUI

/// A single editable task entry
private struct TaskEntry: Identifiable {
    let id = UUID()
    var text: String = ""
}

/// Shown once per day on first app open after wake time — lets user jot down today's tasks
struct MorningTasksView: View {
    @Bindable var store: HabitStore
    @AppStorage("userName") private var userName = ""
    let onDismiss: () -> Void

    @State private var taskEntries: [TaskEntry] = [TaskEntry()]
    @State private var showContent = false
    @FocusState private var focusedId: UUID?

    var body: some View {
        NavigationStack {
            scrollContent
                .linedPaperBackground()
                .safeAreaInset(edge: .bottom) { bottomButton }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Skip") { onDismiss() }
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }
                }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showContent = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedId = taskEntries.first?.id
            }
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                greetingSection
                taskInputSection
                Spacer(minLength: 60)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greetingText)
                .font(.custom("PatrickHand-Regular", size: 28))
                .foregroundStyle(JournalTheme.Colors.navy)

            Text("Jot down your to-dos before you forget!")
                .font(.custom("PatrickHand-Regular", size: 15))
                .foregroundStyle(JournalTheme.Colors.completedGray)
                .lineSpacing(2)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 15)
    }

    // MARK: - Task Input

    private var taskInputSection: some View {
        VStack(spacing: 12) {
            ForEach(Array(taskEntries.enumerated()), id: \.element.id) { index, entry in
                taskRow(entry: entry, index: index)
            }

            addAnotherButton
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 10)
    }

    private func taskRow(entry: TaskEntry, index: Int) -> some View {
        let isFocused = focusedId == entry.id

        return HStack(spacing: 12) {
            Circle()
                .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1.5)
                .frame(width: 22, height: 22)

            TextField("Task \(index + 1)", text: $taskEntries[index].text)
                .font(.custom("PatrickHand-Regular", size: 16))
                .foregroundStyle(JournalTheme.Colors.inkBlack)
                .focused($focusedId, equals: entry.id)
                .submitLabel(index == taskEntries.count - 1 ? .done : .next)
                .onSubmit { handleSubmit(at: index) }

            if taskEntries.count > 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        taskEntries.removeAll { $0.id == entry.id }
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.custom("PatrickHand-Regular", size: 11))
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(JournalTheme.Colors.paperLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isFocused
                                ? JournalTheme.Colors.teal.opacity(0.4)
                                : JournalTheme.Colors.lineLight,
                            lineWidth: 1
                        )
                )
        )
    }

    private var addAnotherButton: some View {
        Button {
            let newEntry = TaskEntry()
            withAnimation(.easeInOut(duration: 0.2)) {
                taskEntries.append(newEntry)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedId = newEntry.id
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.custom("PatrickHand-Regular", size: 13))
                    .foregroundStyle(JournalTheme.Colors.teal)

                Text("Add another task")
                    .font(.custom("PatrickHand-Regular", size: 14))
                    .foregroundStyle(JournalTheme.Colors.teal)

                Spacer()
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        JournalTheme.Colors.teal.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        let hasTasks = hasAnyTasks

        return VStack(spacing: 12) {
            Button {
                saveTasks()
                onDismiss()
            } label: {
                Text(hasTasks ? "Add tasks & start my day" : "Skip for now")
                    .font(.custom("PatrickHand-Regular", size: 16))
                    .foregroundStyle(hasTasks ? Color.white : JournalTheme.Colors.navy)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(hasTasks ? AnyShapeStyle(JournalTheme.Colors.teal) : AnyShapeStyle(Color.clear))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                hasTasks ? Color.clear : JournalTheme.Colors.lineLight,
                                lineWidth: 1.5
                            )
                    )
            }
        }
        .padding(.horizontal, 24)
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

    // MARK: - Helpers

    private var greetingText: String {
        if userName.isEmpty {
            return "Good morning!"
        }
        return "Good morning, \(userName)!"
    }

    private var hasAnyTasks: Bool {
        taskEntries.contains { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func handleSubmit(at index: Int) {
        let trimmed = taskEntries[index].text.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            if index == taskEntries.count - 1 {
                let newEntry = TaskEntry()
                withAnimation(.easeInOut(duration: 0.2)) {
                    taskEntries.append(newEntry)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusedId = newEntry.id
                }
            } else {
                focusedId = taskEntries[index + 1].id
            }
        }
    }

    private func saveTasks() {
        for entry in taskEntries {
            let trimmed = entry.text.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                let _ = store.addHabit(
                    name: trimmed,
                    frequencyType: .once
                )
            }
        }
    }
}
