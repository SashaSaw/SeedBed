import Foundation
import UIKit

/// Service for storing photos in iCloud Documents when sync is enabled.
/// Falls back to local Documents folder when iCloud is unavailable.
final class CloudPhotoService {
    static let shared = CloudPhotoService()

    private let fileManager = FileManager.default
    private let photosDirectoryName = "HobbyPhotos"

    private init() {
        createPhotosDirectoryIfNeeded()
    }

    // MARK: - Directory Management

    /// Returns iCloud Documents container URL if available, otherwise local Documents
    private var baseDirectory: URL {
        if CloudSyncService.shared.isEnabled,
           let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: "iCloud.com.incept5.SeedBed") {
            return iCloudURL.appendingPathComponent("Documents")
        }
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Local documents directory (for fallback and migration)
    private var localDocumentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var photosDirectory: URL {
        baseDirectory.appendingPathComponent(photosDirectoryName)
    }

    private var localPhotosDirectory: URL {
        localDocumentsDirectory.appendingPathComponent(photosDirectoryName)
    }

    private func createPhotosDirectoryIfNeeded() {
        let dirs = [photosDirectory, localPhotosDirectory]
        for dir in dirs {
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    private func habitDirectory(for habitId: UUID) -> URL {
        let dir = photosDirectory.appendingPathComponent(habitId.uuidString)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Photo Operations

    /// Saves a photo for a habit on a specific date
    /// - Parameters:
    ///   - image: The UIImage to save
    ///   - habitId: The habit's UUID
    ///   - date: The date of the completion
    ///   - index: Photo index (0-2) for multiple photos per day
    /// - Returns: The relative path to the saved photo, or nil if save failed
    func savePhoto(_ image: UIImage, for habitId: UUID, on date: Date, index: Int = 0) -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        let filename = index == 0 ? "\(dateString).jpg" : "\(dateString)_\(index).jpg"
        let relativePath = "\(photosDirectoryName)/\(habitId.uuidString)/\(filename)"
        let fullURL = habitDirectory(for: habitId).appendingPathComponent(filename)

        // Compress and save as JPEG
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }

        do {
            try data.write(to: fullURL)

            // If using iCloud, also save locally for immediate access
            if CloudSyncService.shared.isEnabled {
                let localURL = localDocumentsDirectory.appendingPathComponent(relativePath)
                let localDir = localURL.deletingLastPathComponent()
                if !fileManager.fileExists(atPath: localDir.path) {
                    try fileManager.createDirectory(at: localDir, withIntermediateDirectories: true)
                }
                try? data.write(to: localURL)
            }

            return relativePath
        } catch {
            print("Failed to save photo: \(error)")
            return nil
        }
    }

    /// Saves multiple photos for a habit on a specific date
    /// - Returns: Array of relative paths for successfully saved photos
    func savePhotos(_ images: [UIImage], for habitId: UUID, on date: Date) -> [String] {
        var paths: [String] = []
        for (index, image) in images.prefix(3).enumerated() {
            if let path = savePhoto(image, for: habitId, on: date, index: index) {
                paths.append(path)
            }
        }
        return paths
    }

    /// Loads a photo from a relative path
    /// - Parameter relativePath: The relative path stored in DailyLog.photoPath
    /// - Returns: The UIImage, or nil if not found
    func loadPhoto(from relativePath: String) -> UIImage? {
        // Try local first (faster)
        let localURL = localDocumentsDirectory.appendingPathComponent(relativePath)
        if fileManager.fileExists(atPath: localURL.path),
           let data = try? Data(contentsOf: localURL),
           let image = UIImage(data: data) {
            return image
        }

        // Try iCloud if enabled
        if CloudSyncService.shared.isEnabled {
            let iCloudURL = baseDirectory.appendingPathComponent(relativePath)

            // Check if file needs to be downloaded
            if !fileManager.fileExists(atPath: iCloudURL.path) {
                // Trigger download
                try? fileManager.startDownloadingUbiquitousItem(at: iCloudURL)
                return nil // Caller should retry later
            }

            if let data = try? Data(contentsOf: iCloudURL),
               let image = UIImage(data: data) {
                // Cache locally for future access
                try? data.write(to: localURL)
                return image
            }
        }

        return nil
    }

    /// Deletes a photo at the given relative path
    /// - Parameter relativePath: The relative path stored in DailyLog.photoPath
    func deletePhoto(at relativePath: String) {
        // Delete from local
        let localURL = localDocumentsDirectory.appendingPathComponent(relativePath)
        try? fileManager.removeItem(at: localURL)

        // Delete from iCloud if enabled
        if CloudSyncService.shared.isEnabled {
            let iCloudURL = baseDirectory.appendingPathComponent(relativePath)
            try? fileManager.removeItem(at: iCloudURL)
        }
    }

    /// Deletes all photos for a habit
    /// - Parameter habitId: The habit's UUID
    func deleteAllPhotos(for habitId: UUID) {
        let localDir = localPhotosDirectory.appendingPathComponent(habitId.uuidString)
        try? fileManager.removeItem(at: localDir)

        if CloudSyncService.shared.isEnabled {
            let iCloudDir = photosDirectory.appendingPathComponent(habitId.uuidString)
            try? fileManager.removeItem(at: iCloudDir)
        }
    }

    // MARK: - Migration

    /// Migrate local photos to iCloud (called when sync is first enabled)
    func migrateLocalPhotosToCloud() {
        guard CloudSyncService.shared.isEnabled else { return }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            // Get all local photos
            guard let enumerator = self.fileManager.enumerator(
                at: self.localPhotosDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            while let url = enumerator.nextObject() as? URL {
                guard let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                      resourceValues.isRegularFile == true else {
                    continue
                }

                // Get relative path from local photos directory
                let relativePath = url.path.replacingOccurrences(
                    of: self.localPhotosDirectory.path + "/",
                    with: ""
                )

                // Copy to iCloud
                let iCloudURL = self.photosDirectory.appendingPathComponent(relativePath)
                let iCloudDir = iCloudURL.deletingLastPathComponent()

                do {
                    if !self.fileManager.fileExists(atPath: iCloudDir.path) {
                        try self.fileManager.createDirectory(at: iCloudDir, withIntermediateDirectories: true)
                    }
                    if !self.fileManager.fileExists(atPath: iCloudURL.path) {
                        try self.fileManager.copyItem(at: url, to: iCloudURL)
                    }
                } catch {
                    print("Failed to migrate photo to iCloud: \(error)")
                }
            }
        }
    }
}
