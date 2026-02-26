import Foundation
import SwiftData
import CloudKit

/// Main service for managing iCloud sync functionality.
/// Handles opt-in toggle, status tracking, and ModelContainer creation.
@Observable
final class CloudSyncService {
    static let shared = CloudSyncService()

    // MARK: - User Preference

    /// Whether iCloud sync is enabled (stored locally AND synced to cloud)
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") }
        set {
            let oldValue = isEnabled
            UserDefaults.standard.set(newValue, forKey: "iCloudSyncEnabled")

            // Sync this setting to iCloud so it's restored on reinstall/new device
            CloudSettingsService.shared.syncCloudSyncSetting(newValue)

            if newValue && !oldValue {
                // First time enabling - trigger migration
                CloudMigrationService.shared.migrateOnFirstSync()
            }

            // Notify that sync state changed (app may need to restart)
            NotificationCenter.default.post(name: .cloudSyncStateChanged, object: nil)
        }
    }

    // MARK: - Sync Status

    /// Whether a sync is currently in progress
    var isSyncing: Bool = false

    /// Last successful sync date
    var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: "lastCloudSyncDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastCloudSyncDate") }
    }

    /// Total data size in bytes (estimated)
    var totalDataSize: Int64 {
        get { Int64(UserDefaults.standard.integer(forKey: "cloudDataSize")) }
        set { UserDefaults.standard.set(Int(newValue), forKey: "cloudDataSize") }
    }

    // MARK: - Formatted Status

    /// Formatted data size string (e.g., "12.4 MB")
    var dataSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalDataSize, countStyle: .file)
    }

    /// Formatted last sync time (e.g., "2 minutes ago")
    var lastSyncFormatted: String {
        guard let date = lastSyncDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Initialization

    private init() {
        // Start observing CloudKit notifications if enabled
        if isEnabled {
            startObservingCloudKitChanges()
        }
    }

    // MARK: - ModelContainer Creation

    /// Creates a ModelContainer with or without CloudKit sync based on user preference
    /// Uses SownMigrationPlan to handle schema changes between app versions
    func makeModelContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SownSchemaV1.self)

        if isEnabled {
            // CloudKit-enabled configuration
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.incept5.SeedBed")
            )
            return try ModelContainer(
                for: schema,
                migrationPlan: SownMigrationPlan.self,
                configurations: [config]
            )
        } else {
            // Local-only configuration
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            return try ModelContainer(
                for: schema,
                migrationPlan: SownMigrationPlan.self,
                configurations: [config]
            )
        }
    }

    // MARK: - Sync Monitoring

    private func startObservingCloudKitChanges() {
        // Observe CloudKit import notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NSPersistentStoreRemoteChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleRemoteChange()
        }
    }

    private func handleRemoteChange() {
        // Update sync status
        lastSyncDate = Date()
        isSyncing = false

        // Recalculate data size (rough estimate)
        updateDataSizeEstimate()
    }

    /// Mark sync as started (called when app becomes active)
    func markSyncStarted() {
        guard isEnabled else { return }
        isSyncing = true
    }

    /// Mark sync as completed
    func markSyncCompleted() {
        isSyncing = false
        lastSyncDate = Date()
        updateDataSizeEstimate()
    }

    /// Update the estimated data size based on database file size
    private func updateDataSizeEstimate() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let fileManager = FileManager.default
            guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

            var totalSize: Int64 = 0

            // SwiftData stores files in Application Support
            if let enumerator = fileManager.enumerator(at: appSupport, includingPropertiesForKeys: [.fileSizeKey]) {
                while let url = enumerator.nextObject() as? URL {
                    if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalSize += Int64(size)
                    }
                }
            }

            // Add photos directory size
            let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            if let photosDir = documentsDir?.appendingPathComponent("HobbyPhotos"),
               let enumerator = fileManager.enumerator(at: photosDir, includingPropertiesForKeys: [.fileSizeKey]) {
                while let url = enumerator.nextObject() as? URL {
                    if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalSize += Int64(size)
                    }
                }
            }

            DispatchQueue.main.async {
                self?.totalDataSize = totalSize
            }
        }
    }

    /// Check iCloud availability
    var isCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// Whether an iCloud backup exists (cloud zones or iCloud Documents found)
    var hasCloudBackup: Bool = false

    /// Check if any cloud data exists (call on appear)
    func checkForExistingBackup() {
        guard isCloudAvailable else {
            hasCloudBackup = false
            return
        }

        Task {
            var found = false

            // Check for CloudKit zones
            do {
                let container = CKContainer(identifier: "iCloud.com.incept5.SeedBed")
                let zones = try await container.privateCloudDatabase.allRecordZones()
                if !zones.isEmpty { found = true }
            } catch {
                // If we can't check, fall back to other signals
            }

            // Check for iCloud Documents folder
            if !found {
                let fileManager = FileManager.default
                if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: "iCloud.com.incept5.SeedBed") {
                    let docsURL = iCloudURL.appendingPathComponent("Documents")
                    if fileManager.fileExists(atPath: docsURL.path) {
                        found = true
                    }
                }
            }

            // Check for NSUbiquitousKeyValueStore data
            if !found {
                let kvStore = NSUbiquitousKeyValueStore.default
                if !kvStore.dictionaryRepresentation.isEmpty { found = true }
            }

            await MainActor.run {
                hasCloudBackup = found
            }
        }
    }

    // MARK: - Delete Cloud Data

    /// Deletes all iCloud data: CloudKit database zone, iCloud Documents (photos), and key-value store settings.
    /// After deletion, disables sync and requires app restart.
    func deleteCloudData() async {
        let fileManager = FileManager.default

        // 1. Delete CloudKit private database zone
        // CKRecordZone.ID for SwiftData's default zone
        do {
            let container = CKContainer(identifier: "iCloud.com.incept5.SeedBed")
            let database = container.privateCloudDatabase
            let zones = try await database.allRecordZones()
            for zone in zones {
                try await database.deleteRecordZone(withID: zone.zoneID)
            }
            print("CloudSyncService: Deleted \(zones.count) CloudKit zone(s)")
        } catch {
            print("CloudSyncService: Failed to delete CloudKit zones: \(error)")
        }

        // 2. Delete iCloud Documents (photos)
        if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: "iCloud.com.incept5.SeedBed") {
            let docsURL = iCloudURL.appendingPathComponent("Documents")
            if fileManager.fileExists(atPath: docsURL.path) {
                try? fileManager.removeItem(at: docsURL)
                print("CloudSyncService: Deleted iCloud Documents folder")
            }
        }

        // 3. Clear NSUbiquitousKeyValueStore (synced settings)
        let kvStore = NSUbiquitousKeyValueStore.default
        for key in kvStore.dictionaryRepresentation.keys {
            kvStore.removeObject(forKey: key)
        }
        kvStore.synchronize()
        print("CloudSyncService: Cleared iCloud key-value store")

        // 4. Disable sync locally and clear backup state
        await MainActor.run {
            UserDefaults.standard.set(false, forKey: "iCloudSyncEnabled")
            isSyncing = false
            lastSyncDate = nil
            totalDataSize = 0
            hasCloudBackup = false
            NotificationCenter.default.post(name: .cloudSyncStateChanged, object: nil)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let cloudSyncStateChanged = Notification.Name("cloudSyncStateChanged")
}
