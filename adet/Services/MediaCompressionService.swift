import Foundation
import UIKit

@MainActor
class MediaCompressionService: ObservableObject, Sendable {
    static let shared = MediaCompressionService()

    private init() {}

    // MARK: - Image Compression

    /// Compress a UIImage to a target file size and quality, returning a UIImage.
    func compressImage(
        _ image: UIImage,
        maxFileSize: Int = 1_000_000, // 1MB default
        quality: CGFloat = 0.8
    ) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            Task.detached {
                let compressedImage = await MediaCompressionService.performImageCompression(
                    image,
                    maxFileSize: maxFileSize,
                    quality: quality
                )
                continuation.resume(returning: compressedImage)
            }
        }
    }

    /// Compress a UIImage and return JPEG Data for upload (recommended for proof uploads)
    func compressImageData(
        _ image: UIImage,
        maxFileSize: Int = 1_000_000,
        quality: CGFloat = 0.8
    ) async -> Data? {
        guard let compressedImage = await compressImage(image, maxFileSize: maxFileSize, quality: quality) else {
            return nil
        }
        return compressedImage.jpegData(compressionQuality: quality)
    }

    /// Static utility for one-shot compression to Data (for use in sync contexts)
    static func compressImageToData(
        _ image: UIImage,
        maxFileSize: Int = 1_000_000,
        quality: CGFloat = 0.8
    ) -> Data? {
        guard let compressed = performImageCompression(image, maxFileSize: maxFileSize, quality: quality) else { return nil }
        return compressed.jpegData(compressionQuality: quality)
    }

    // MARK: - Private Methods

    private static func performImageCompression(
        _ image: UIImage,
        maxFileSize: Int,
        quality: CGFloat
    ) -> UIImage? {
        var compressionQuality = quality
        var imageData = image.jpegData(compressionQuality: compressionQuality)

        // Reduce quality until file size is acceptable
        while let data = imageData, data.count > maxFileSize && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            imageData = image.jpegData(compressionQuality: compressionQuality)
        }

        guard let finalData = imageData else { return nil }
        return UIImage(data: finalData)
    }
}

// USAGE EXAMPLE (in your proof upload flow):
// let compressedData = await MediaCompressionService.shared.compressImageData(selectedUIImage)
// Use compressedData for your multipart upload to the backend
