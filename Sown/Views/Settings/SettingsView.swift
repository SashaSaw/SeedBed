import SwiftUI

/// Main settings view — shown as a tab
struct SettingsView: View {
    @Bindable var store: HabitStore
    @State private var schedule = UserSchedule.shared
    @State private var showingBlockSetup = false
    @AppStorage("soundEffectsEnabled") private var soundEffectsEnabled = true
    @AppStorage("userName") private var userName = ""
    @State private var editingName = ""
    @State private var isEditingName = false
    @State private var cloudSync = CloudSyncService.shared
    @State private var showingRestartAlert = false
    @State private var showingDeleteCloudAlert = false
    @State private var isDeletingCloudData = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Name/greeting section
                    nameCard

                    // App Blocking button
                    Button {
                        Feedback.buttonPress()
                        showingBlockSetup = true
                    } label: {
                        HStack {
                            Image(systemName: "lock.shield")
                                .font(.custom("PatrickHand-Regular", size: 18))
                                .foregroundStyle(JournalTheme.Colors.amber)

                            Text("App Blocking")
                                .font(.custom("PatrickHand-Regular", size: 17))
                                .foregroundStyle(JournalTheme.Colors.inkBlack)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.custom("PatrickHand-Regular", size: 14))
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
                    }
                    .buttonStyle(.plain)

                    // iCloud Backup section
                    iCloudBackupCard

                    // Smart Reminders section
                    SmartReminderSettingsCard()

                    // AI Assistant
                    AISettingsCard()

                    // HealthKit integration
                    HealthKitSettingsCard()

                    // Screen Time integration
                    ScreenTimeSettingsCard()

                    // Sound Effects toggle
                    HStack {
                        Image(systemName: soundEffectsEnabled ? "speaker.wave.2" : "speaker.slash")
                            .font(.custom("PatrickHand-Regular", size: 18))
                            .foregroundStyle(JournalTheme.Colors.teal)
                            .frame(width: 24)

                        Text("Sound Effects")
                            .font(.custom("PatrickHand-Regular", size: 17))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)

                        Spacer()

                        Toggle("", isOn: $soundEffectsEnabled)
                            .tint(JournalTheme.Colors.teal)
                            .labelsHidden()
                            .onChange(of: soundEffectsEnabled) { _, _ in
                                Feedback.selection()
                            }
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

                    // Archived Habits
                    NavigationLink {
                        ArchivedHabitsListView(store: store)
                            .onAppear { Feedback.sheetOpen() }
                    } label: {
                        HStack {
                            Image(systemName: "archivebox")
                                .font(.custom("PatrickHand-Regular", size: 18))
                                .foregroundStyle(JournalTheme.Colors.completedGray)

                            Text("Archived Habits")
                                .font(.custom("PatrickHand-Regular", size: 17))
                                .foregroundStyle(JournalTheme.Colors.inkBlack)

                            Spacer()

                            if !store.archivedHabits.isEmpty {
                                Text("\(store.archivedHabits.count)")
                                    .font(.custom("PatrickHand-Regular", size: 14))
                                    .foregroundStyle(JournalTheme.Colors.completedGray)
                            }

                            Image(systemName: "chevron.right")
                                .font(.custom("PatrickHand-Regular", size: 14))
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
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .linedPaperBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingBlockSetup) {
                BlockSetupView()
                    .onAppear { Feedback.sheetOpen() }
            }
            .alert("Restart Required", isPresented: $showingRestartAlert) {
                Button("OK") { }
            } message: {
                Text("Please restart the app for iCloud sync changes to take effect.")
            }
            .alert("Delete iCloud Backup?", isPresented: $showingDeleteCloudAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    isDeletingCloudData = true
                    Task {
                        await cloudSync.deleteCloudData()
                        await MainActor.run {
                            isDeletingCloudData = false
                            showingRestartAlert = true
                        }
                    }
                }
            } message: {
                Text("This will permanently delete all your data from iCloud, including habits, logs, and photos. Your local data will not be affected. This cannot be undone.")
            }
            .onChange(of: schedule.wakeTimeMinutes) { _, _ in
                store.refreshSmartReminders()
            }
            .onChange(of: schedule.bedTimeMinutes) { _, _ in
                store.refreshSmartReminders()
            }
            .onChange(of: schedule.smartRemindersEnabled) { _, newValue in
                if newValue {
                    store.refreshSmartReminders()
                }
            }
        }
    }

    // MARK: - Name Card

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle")
                    .font(.custom("PatrickHand-Regular", size: 18))
                    .foregroundStyle(JournalTheme.Colors.teal)

                Text("Your Name")
                    .font(.custom("PatrickHand-Regular", size: 17))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
            }

            if isEditingName {
                // Editing mode
                VStack(spacing: 12) {
                    TextField("Enter your name", text: $editingName)
                        .font(.custom("PatrickHand-Regular", size: 16))
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

                    HStack(spacing: 12) {
                        Button {
                            Feedback.buttonPress()
                            isEditingName = false
                            editingName = userName
                        } label: {
                            Text("Cancel")
                                .font(.custom("PatrickHand-Regular", size: 14))
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(JournalTheme.Colors.lineLight, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            Feedback.buttonPress()
                            userName = editingName.trimmingCharacters(in: .whitespaces)
                            isEditingName = false
                        } label: {
                            Text("Save")
                                .font(.custom("PatrickHand-Regular", size: 14))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(JournalTheme.Colors.teal)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                // Display mode
                HStack {
                    if userName.isEmpty {
                        Text("Not set")
                            .font(.custom("PatrickHand-Regular", size: 15))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                            .italic()
                    } else {
                        Text(userName)
                            .font(.custom("PatrickHand-Regular", size: 16))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)
                    }

                    Spacer()

                    if !userName.isEmpty {
                        Button {
                            Feedback.buttonPress()
                            userName = ""
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundStyle(JournalTheme.Colors.negativeRedDark)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        Feedback.buttonPress()
                        editingName = userName
                        isEditingName = true
                    } label: {
                        Text(userName.isEmpty ? "Add" : "Edit")
                            .font(.custom("PatrickHand-Regular", size: 14))
                            .foregroundStyle(JournalTheme.Colors.teal)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Your name appears in the daily greeting on the Today tab.")
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
    }

    // MARK: - iCloud Backup Card

    private var iCloudBackupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "icloud")
                    .font(.custom("PatrickHand-Regular", size: 18))
                    .foregroundStyle(JournalTheme.Colors.navy)

                Text("iCloud Backup")
                    .font(.custom("PatrickHand-Regular", size: 17))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)
            }

            // Toggle
            HStack {
                Text("Enable iCloud Sync")
                    .font(.custom("PatrickHand-Regular", size: 15))
                    .foregroundStyle(JournalTheme.Colors.inkBlack)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { cloudSync.isEnabled },
                    set: { newValue in
                        Feedback.selection()
                        let wasEnabled = cloudSync.isEnabled
                        cloudSync.isEnabled = newValue

                        // Show restart alert when toggling
                        if newValue != wasEnabled {
                            showingRestartAlert = true
                        }
                    }
                ))
                .tint(JournalTheme.Colors.navy)
                .labelsHidden()
            }

            // Status info (only shown when enabled)
            if cloudSync.isEnabled {
                VStack(spacing: 8) {
                    // Backup status
                    HStack {
                        Text("Backup Status")
                            .font(.custom("PatrickHand-Regular", size: 14))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)
                        Spacer()
                        Text(cloudSync.dataSizeFormatted)
                            .font(.custom("PatrickHand-Regular", size: 14))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }

                    // Last synced
                    HStack {
                        Text("Last synced")
                            .font(.custom("PatrickHand-Regular", size: 14))
                            .foregroundStyle(JournalTheme.Colors.inkBlack)
                        Spacer()
                        Text(cloudSync.lastSyncFormatted)
                            .font(.custom("PatrickHand-Regular", size: 14))
                            .foregroundStyle(JournalTheme.Colors.completedGray)
                    }

                    // Syncing indicator
                    if cloudSync.isSyncing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Syncing...")
                                .font(.custom("PatrickHand-Regular", size: 14))
                                .foregroundStyle(JournalTheme.Colors.completedGray)
                            Spacer()
                        }
                    }
                }
            }

            // Footer text
            Text("Your data syncs automatically when connected to the internet.")
                .font(.custom("PatrickHand-Regular", size: 12))
                .foregroundStyle(JournalTheme.Colors.completedGray)

            // iCloud unavailable warning
            if !cloudSync.isCloudAvailable && cloudSync.isEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundStyle(JournalTheme.Colors.amber)
                    Text("iCloud unavailable. Sign in to iCloud in Settings.")
                        .font(.custom("PatrickHand-Regular", size: 12))
                        .foregroundStyle(JournalTheme.Colors.amber)
                }
            }

            // Delete cloud backup button — shown when a backup is detected
            if cloudSync.hasCloudBackup {
                Button {
                    Feedback.buttonPress()
                    showingDeleteCloudAlert = true
                } label: {
                    HStack(spacing: 6) {
                        if isDeletingCloudData {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.red)
                        } else {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                        }
                        Text(isDeletingCloudData ? "Deleting..." : "Delete iCloud Backup")
                            .font(.custom("PatrickHand-Regular", size: 14))
                    }
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .disabled(isDeletingCloudData)
            }
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
            cloudSync.checkForExistingBackup()
        }
    }
}
