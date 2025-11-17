import UIKit
import SwiftUI

class ImageManager {
    static let shared = ImageManager()

    private let fileManager = FileManager.default
    private var receiptsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("receipts")
    }

    private init() {
        createReceiptsDirectoryIfNeeded()
    }

    private func createReceiptsDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: receiptsDirectory.path) {
            try? fileManager.createDirectory(at: receiptsDirectory, withIntermediateDirectories: true)
        }
    }

    func saveImage(_ image: UIImage) -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }

        let filename = "\(UUID().uuidString).jpg"
        let fileURL = receiptsDirectory.appendingPathComponent(filename)

        do {
            try imageData.write(to: fileURL)
            return filename
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }

    func loadImage(_ filename: String) -> UIImage? {
        let fileURL = receiptsDirectory.appendingPathComponent(filename)
        guard let imageData = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return UIImage(data: imageData)
    }

    func deleteImage(_ filename: String) {
        let fileURL = receiptsDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }

    func deleteImages(_ filenames: [String]) {
        filenames.forEach { deleteImage($0) }
    }

    func getImageURL(_ filename: String) -> URL {
        return receiptsDirectory.appendingPathComponent(filename)
    }
}
