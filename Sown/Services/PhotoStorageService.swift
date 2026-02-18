import Foundation
import UIKit

/// Service for saving, loading, and deleting hobby photos.
/// Delegates to CloudPhotoService when iCloud sync is enabled.
final class PhotoStorageService {
    static let shared = PhotoStorageService()

    private let fileManager = FileManager.default
    private let photosDirectoryName = "HobbyPhotos"
    private let cloudPhotoService = CloudPhotoService.shared

    private init() {
        // Ensure photos directory exists
        createPhotosDirectoryIfNeeded()
    }

    // MARK: - Directory Management

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var photosDirectory: URL {
        documentsDirectory.appendingPathComponent(photosDirectoryName)
    }

    private func createPhotosDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: photosDirectory.path) {
            try? fileManager.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
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
        // Delegate to cloud service when sync is enabled
        if CloudSyncService.shared.isEnabled {
            return cloudPhotoService.savePhoto(image, for: habitId, on: date, index: index)
        }

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
            return relativePath
        } catch {
            print("Failed to save photo: \(error)")
            return nil
        }
    }

    /// Saves multiple photos for a habit on a specific date
    /// - Returns: Array of relative paths for successfully saved photos
    func savePhotos(_ images: [UIImage], for habitId: UUID, on date: Date) -> [String] {
        // Delegate to cloud service when sync is enabled
        if CloudSyncService.shared.isEnabled {
            return cloudPhotoService.savePhotos(images, for: habitId, on: date)
        }

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
        // Delegate to cloud service when sync is enabled
        if CloudSyncService.shared.isEnabled {
            return cloudPhotoService.loadPhoto(from: relativePath)
        }

        let fullURL = documentsDirectory.appendingPathComponent(relativePath)
        guard fileManager.fileExists(atPath: fullURL.path),
              let data = try? Data(contentsOf: fullURL),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    /// Deletes a photo at the given relative path
    /// - Parameter relativePath: The relative path stored in DailyLog.photoPath
    func deletePhoto(at relativePath: String) {
        // Delegate to cloud service when sync is enabled
        if CloudSyncService.shared.isEnabled {
            cloudPhotoService.deletePhoto(at: relativePath)
            return
        }

        let fullURL = documentsDirectory.appendingPathComponent(relativePath)
        try? fileManager.removeItem(at: fullURL)
    }

    /// Deletes all photos for a habit
    /// - Parameter habitId: The habit's UUID
    func deleteAllPhotos(for habitId: UUID) {
        // Delegate to cloud service when sync is enabled
        if CloudSyncService.shared.isEnabled {
            cloudPhotoService.deleteAllPhotos(for: habitId)
            return
        }

        let habitDir = habitDirectory(for: habitId)
        try? fileManager.removeItem(at: habitDir)
    }
}
