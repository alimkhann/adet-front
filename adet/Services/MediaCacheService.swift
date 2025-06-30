import SwiftUI
import Kingfisher
import OSLog

class MediaCacheService {
    static let shared = MediaCacheService()
    private let logger = Logger(subsystem: "com.adet.media", category: "MediaCacheService")

    private init() {
        configureKingfisher()
    }

    private func configureKingfisher() {
        // Configure memory cache
        KingfisherManager.shared.cache.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024 // 100MB

        // Configure disk cache
        KingfisherManager.shared.cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024 // 500MB
        KingfisherManager.shared.cache.diskStorage.config.expiration = .days(7) // 7 days

        logger.info("Kingfisher cache configured successfully")
    }

    // MARK: - Image Loading with Caching

    func loadImage(from url: String, completion: @escaping (UIImage?) -> Void) {
        guard let imageURL = URL(string: url) else {
            logger.error("Invalid URL: \(url)")
            completion(nil)
            return
        }

        KingfisherManager.shared.retrieveImage(with: imageURL) { result in
            switch result {
            case .success(let value):
                self.logger.info("Successfully loaded image from: \(url)")
                completion(value.image)
            case .failure(let error):
                self.logger.error("Failed to load image from \(url): \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    // MARK: - SwiftUI AsyncImage with Caching

    func cachedAsyncImage(url: String) -> some View {
        KFImage(URL(string: url))
            .placeholder {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            .retry(maxCount: 3)
            .fade(duration: 0.25)
            .onSuccess { result in
                self.logger.info("Successfully loaded cached image")
            }
            .onFailure { error in
                self.logger.error("Failed to load cached image: \(error.localizedDescription)")
            }
    }

    // MARK: - Profile Image with Caching

    func profileImage(url: String?, size: CGFloat) -> some View {
        if let url = url, !url.isEmpty {
            KFImage(URL(string: url))
                .placeholder {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: size * 0.6))
                        .foregroundColor(.gray)
                }
                .retry(maxCount: 2)
                .fade(duration: 0.2)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .onSuccess { _ in
                    self.logger.debug("Profile image loaded successfully")
                }
        } else {
            Image(systemName: "person.circle.fill")
                .font(.system(size: size * 0.6))
                .foregroundColor(.gray)
                .frame(width: size, height: size)
        }
    }

    // MARK: - Cache Management

    func clearCache() {
        KingfisherManager.shared.cache.clearMemoryCache()
        KingfisherManager.shared.cache.clearDiskCache {
            self.logger.info("Cache cleared successfully")
        }
    }

    func getCacheSize(completion: @escaping (UInt) -> Void) {
        KingfisherManager.shared.cache.calculateDiskStorageSize { result in
            switch result {
            case .success(let size):
                completion(size)
            case .failure:
                completion(0)
            }
        }
    }

    // MARK: - Preload Images

    func preloadImages(urls: [String]) {
        let imageURLs = urls.compactMap { URL(string: $0) }
        let prefetcher = ImagePrefetcher(urls: imageURLs)
        prefetcher.start()

        logger.info("Started preloading \(imageURLs.count) images")
    }
}