import UIKit
import AVFoundation
import OSLog

class MediaCompressionService {
    static let shared = MediaCompressionService()
    private let logger = Logger(subsystem: "com.adet.media", category: "MediaCompressionService")

    private init() {}

    // MARK: - Image Compression

    func compressImage(_ image: UIImage, maxFileSize: Int = 1_000_000, compressionQuality: CGFloat = 0.8) -> Data? {
        logger.info("Starting image compression with max size: \(maxFileSize) bytes")

        // Resize image if needed
        let resizedImage = resizeImage(image, maxDimension: 1080)

        // Try different compression qualities
        var quality = compressionQuality
        var imageData = resizedImage.jpegData(compressionQuality: quality)

        while let data = imageData, data.count > maxFileSize && quality > 0.1 {
            quality -= 0.1
            imageData = resizedImage.jpegData(compressionQuality: quality)
        }

        if let finalData = imageData {
            logger.info("Image compressed successfully. Final size: \(finalData.count) bytes, quality: \(quality)")
        } else {
            logger.error("Failed to compress image")
        }

        return imageData
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let aspectRatio = size.width / size.height

        var newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        // Don't upscale images
        if newSize.width > size.width || newSize.height > size.height {
            return image
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }

    // MARK: - Profile Image Compression

    func compressProfileImage(_ image: UIImage) -> Data? {
        logger.info("Compressing profile image")
        return compressImage(image, maxFileSize: 500_000, compressionQuality: 0.9)
    }

    // MARK: - Post Image Compression

    func compressPostImage(_ image: UIImage) -> Data? {
        logger.info("Compressing post image")
        return compressImage(image, maxFileSize: 2_000_000, compressionQuality: 0.85)
    }

    // MARK: - Video Compression (Basic)

    func compressVideo(url: URL, completion: @escaping (URL?) -> Void) {
        logger.info("Starting video compression for URL: \(url)")

        let asset = AVURLAsset(url: url)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            logger.error("Failed to create export session")
            completion(nil)
            return
        }

        let outputURL = getTemporaryVideoURL()
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    self.logger.info("Video compression completed successfully")
                    completion(outputURL)
                case .failed:
                    self.logger.error("Video compression failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
                    completion(nil)
                case .cancelled:
                    self.logger.info("Video compression cancelled")
                    completion(nil)
                default:
                    completion(nil)
                }
            }
        }
    }

    private func getTemporaryVideoURL() -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "compressed_video_\(UUID().uuidString).mp4"
        return tempDirectory.appendingPathComponent(fileName)
    }
}