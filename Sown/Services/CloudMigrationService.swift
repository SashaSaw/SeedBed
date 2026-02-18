import Foundation

/// Service for handling migration when iCloud sync is first enabled.
/// Pushes local settings to cloud and initiates photo migration.
final class CloudMigrationService {
    static let shared = CloudMigrationService()

    private let migrationKey = "hasCompletedCloudMigration"

    private init() {}

    // MARK: - Migration

    /// Called when user first enables iCloud sync
    func migrateOnFirstSync() {
        // Check if already migrated
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        // Push settings to cloud
        CloudSettingsService.shared.pushAllSettingsToCloud()

        // Migrate photos in background
        CloudPhotoService.shared.migrateLocalPhotosToCloud()

        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: migrationKey)

        // Update sync status
        CloudSyncService.shared.markSyncStarted()

        // Schedule completion check
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            CloudSyncService.shared.markSyncCompleted()
        }
    }

    /// Reset migration state (for testing or re-migration)
    func resetMigrationState() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
    }
}
