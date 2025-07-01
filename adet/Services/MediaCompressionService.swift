import Foundation
import UIKit

@MainActor
class MediaCompressionService: ObservableObject, Sendable {
    static let shared = MediaCompressionService()

    private init() {}

    // MARK: - Image Compression

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
