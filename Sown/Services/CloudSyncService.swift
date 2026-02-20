import Foundation
import SwiftData

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
}

// MARK: - Notification Names

extension Notification.Name {
    static let cloudSyncStateChanged = Notification.Name("cloudSyncStateChanged")
}
