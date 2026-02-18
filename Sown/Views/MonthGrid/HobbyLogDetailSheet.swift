import SwiftUI

/// Wrapper to make UIImage identifiable for sheet presentation
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Helper struct for hobby log sheet presentation (used by both MonthGridView and HabitDetailView)
struct HobbyLogSelection: Identifiable {
    let id = UUID()
    let habit: Habit
    let date: Date
}

/// Helper struct for group hobby log sheet presentation
struct GroupHobbyLogSelection: Identifiable {
    let id = UUID()
    let group: HabitGroup
    let date: Date
    let habits: [Habit] // Sub-habits with hobby content

    init(group: HabitGroup, date: Date, allHabits: [Habit]) {
        self.group = group
        self.date = date
        self.habits = allHabits.filter { habit in
            group.habitIds.contains(habit.id) &&
            habit.isHobby &&
            habit.isCompleted(for: date) &&
            habit.log(for: date)?.hasContent == true
        }
    }
}

/// Sheet to view notes and photos from a hobby log in the month grid
struct HobbyLogDetailSheet: View {
    let habit: Habit
    let date: Date
    let onDismiss: () -> Void
    var store: HabitStore? = nil // When provided, editing is enabled

    @State private var loadedImages: [UIImage] = []
    @State private var currentLog: DailyLog? = nil
    @State private var isEditing = false
    @State private var editNote: String = ""
    @State private var editImages: [IdentifiableImage] = []
    @State private var showingImageSourcePicker = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false

    private let maxPhotos = 3

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Habit name
                    Text(habit.name)
                        .font(.custom("PatrickHand-Regular", size: 24))
                        .foregroundStyle(JournalTheme.Colors.inkBlack)

                    // Date right above the log content
                    Text(dateFormatter.string(from: date))
                        .font(JournalTheme.Fonts.habitCriteria())
                        .foregroundStyle(JournalTheme.Colors.completedGray)

                    if isEditing {
                        editModeContent
                    } else {
                        viewModeContent
                    }

                    Spacer(minLength: 50)
                }
                .padding()
            }
            .linedPaperBackground()
            .navigationTitle("Hobby Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            Feedback.buttonPress()
                            isEditing = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Feedback.buttonPress()
                            saveEdits()
                        }
                        .fontWeight(.semibold)
                    }
                } else {
                    if store != nil {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                startEditing()
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            onDismiss()
                        }
                    }
                }
            }
        }
        .onAppear {
            loadData()
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(sourceType: .camera) { image in
                if editImages.count < maxPhotos {
                    editImages.append(IdentifiableImage(image: image))
                }
            }
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            ImagePicker(sourceType: .photoLibrary) { image in
                if editImages.count < maxPhotos {
                    editImages.append(IdentifiableImage(image: image))
                }
            }
        }
    }

    // MARK: - View Mode

    @ViewBuilder
    private var viewModeContent: some View {
        // Photo section — full-width snapping pager
        if !loadedImages.isEmpty {
            VStack(spacing: 8) {
                TabView {
                    ForEach(Array(loadedImages.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 300)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                            .padding(.horizontal, 4)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: loadedImages.count > 1 ? .always : .never))
                .frame(height: 320)
            }
        }

        // Note section
        if let log = currentLog, let note = log.note, !note.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(JournalTheme.Fonts.sectionHeader())
                    .foregroundStyle(JournalTheme.Colors.inkBlue)

                Text(note)
                    .font(JournalTheme.Fonts.habitName())
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.7))
                            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                    )
            }
        }

        // Empty state
        if loadedImages.isEmpty && (currentLog?.note == nil || currentLog?.note?.isEmpty == true) {
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.custom("PatrickHand-Regular", size: 48))
                    .foregroundStyle(JournalTheme.Colors.completedGray)

                Text("No photo or notes recorded")
                    .font(JournalTheme.Fonts.habitName())
                    .foregroundStyle(JournalTheme.Colors.completedGray)

                if store != nil {
                    Button {
                        startEditing()
                    } label: {
                        Text("Add Notes & Photos")
                            .font(.custom("PatrickHand-Regular", size: 16))
                            .foregroundStyle(JournalTheme.Colors.inkBlue)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .stroke(JournalTheme.Colors.inkBlue, lineWidth: 1.5)
                            )
                    }
                    .padding(.top, 4)
                } else {
                    Text("Photos and notes are added when completing a hobby")
                        .font(JournalTheme.Fonts.habitCriteria())
                        .foregroundStyle(JournalTheme.Colors.completedGray)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    // MARK: - Edit Mode

    @ViewBuilder
    private var editModeContent: some View {
        // Photo editing — horizontal row with add/remove
        VStack(alignment: .leading, spacing: 8) {
            Text("Photos")
                .font(JournalTheme.Fonts.sectionHeader())
                .foregroundStyle(JournalTheme.Colors.inkBlue)

            HStack(spacing: 12) {
                ForEach(editImages) { item in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: item.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(JournalTheme.Colors.inkBlue, lineWidth: 1.5)
                            )

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                editImages.removeAll { $0.id == item.id }
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.custom("PatrickHand-Regular", size: 18))
                                .foregroundStyle(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)).frame(width: 16, height: 16))
                        }
                        .offset(x: 4, y: -4)
                    }
                }

                if editImages.count < maxPhotos {
                    Button {
                        showingImageSourcePicker = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "camera")
                                .font(.custom("PatrickHand-Regular", size: 24))
                                .foregroundStyle(JournalTheme.Colors.completedGray)

                            Text(editImages.isEmpty ? "Add Photo" : "+")
                                .font(.custom("PatrickHand-Regular", size: 10))
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                        }
                        .frame(width: 80, height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                        )
                    }
                    .confirmationDialog("Add Photo", isPresented: $showingImageSourcePicker) {
                        if ImagePicker.isCameraAvailable {
                            Button("Take Photo") {
                                showingCamera = true
                            }
                        }
                        Button("Choose from Library") {
                            showingPhotoLibrary = true
                        }
                    }
                }
            }
        }

        // Note editing
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(JournalTheme.Fonts.sectionHeader())
                .foregroundStyle(JournalTheme.Colors.inkBlue)

            TextEditor(text: $editNote)
                .font(JournalTheme.Fonts.habitName())
                .foregroundStyle(JournalTheme.Colors.inkBlack)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(JournalTheme.Colors.lineLight, lineWidth: 1)
                )
        }
    }

    // MARK: - Actions

    private func startEditing() {
        editNote = currentLog?.note ?? ""
        editImages = loadedImages.map { IdentifiableImage(image: $0) }
        isEditing = true
    }

    private func saveEdits() {
        guard let store = store else { return }
        let noteToSave = editNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editNote
        store.updateHobbyLog(for: habit, on: date, note: noteToSave, images: editImages.map(\.image))

        // Reload data to reflect changes
        loadData()
        isEditing = false
    }

    private func loadData() {
        // Find the log for this date
        currentLog = habit.dailyLogs?.first { log in
            Calendar.current.isDate(log.date, inSameDayAs: date) && log.completed
        }

        guard let log = currentLog else { return }

        // Load all photos (merges legacy single photo + new multi-photo paths)
        loadedImages = log.allPhotoPaths.compactMap {
            PhotoStorageService.shared.loadPhoto(from: $0)
        }
    }
}

/// Sheet to view hobby logs from all sub-habits in a group for a given date
struct GroupHobbyLogSheet: View {
    let group: HabitGroup
    let date: Date
    let habits: [Habit]
    let onDismiss: () -> Void

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.name)
                            .font(.custom("PatrickHand-Regular", size: 24))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)

                        Text(dateFormatter.string(from: date))
                            .font(JournalTheme.Fonts.habitCriteria())
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }
                    .padding(.bottom, 8)

                    // Sub-habit logs
                    ForEach(habits) { habit in
                        GroupSubHabitLogView(habit: habit, date: date)
                    }

                    if habits.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.custom("PatrickHand-Regular", size: 48))
                                .foregroundStyle(JournalTheme.Colors.completedGray)

                            Text("No hobby logs for this date")
                                .font(JournalTheme.Fonts.habitName())
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }

                    Spacer(minLength: 50)
                }
                .padding()
            }
            .linedPaperBackground()
            .navigationTitle("Group Hobby Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

/// A sub-habit's hobby log within a group sheet
struct GroupSubHabitLogView: View {
    let habit: Habit
    let date: Date

    @State private var loadedImages: [UIImage] = []
    @State private var currentLog: DailyLog? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Sub-habit name
            Text(habit.name)
                .font(.custom("PatrickHand-Regular", size: 18))
                .foregroundStyle(JournalTheme.Colors.inkBlue)

            // Photos
            if !loadedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(loadedImages.enumerated()), id: \.offset) { _, image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 150, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        }
                    }
                }
            }

            // Note
            if let log = currentLog, let note = log.note, !note.isEmpty {
                Text(note)
                    .font(JournalTheme.Fonts.habitName())
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.5))
                    )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.7))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
        .onAppear {
            loadData()
        }
    }

    private func loadData() {
        currentLog = habit.dailyLogs?.first { log in
            Calendar.current.isDate(log.date, inSameDayAs: date) && log.completed
        }

        guard let log = currentLog else { return }

        loadedImages = log.allPhotoPaths.compactMap {
            PhotoStorageService.shared.loadPhoto(from: $0)
        }
    }
}
