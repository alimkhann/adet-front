import Foundation
import UIKit

class MediaCacheService: ObservableObject {
    static let shared = MediaCacheService()

    private let cache = NSCache<NSString, UIImage>()
    private let maxCacheSize: Int = 100 * 1024 * 1024 // 100MB

    private init() {
        cache.totalCostLimit = maxCacheSize
        setupMemoryWarningNotification()
    }

    // MARK: - Cache Operations

    func cacheImage(_ image: UIImage, forKey key: String) {
        let cost = estimateImageMemorySize(image)
        cache.setObject(image, forKey: NSString(string: key), cost: cost)
    }

    func getCachedImage(forKey key: String) -> UIImage? {
        return cache.object(forKey: NSString(string: key))
    }

    func removeCachedImage(forKey key: String) {
        cache.removeObject(forKey: NSString(string: key))
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    // MARK: - Helper Methods

    private func estimateImageMemorySize(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }

    private func setupMemoryWarningNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        clearCache()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}