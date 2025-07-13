import SwiftUI
import UIKit

struct ProfileImageView: View {
    let user: User
    let size: CGFloat
    let isEditable: Bool
    let onImageTap: (() -> Void)?
    let onDeleteTap: (() -> Void)?
    let jwtToken: String?

    @State private var isLoading = false

    var cacheBustedProfileImageUrl: URL? {
        guard let urlString = user.profileImageUrl, !urlString.isEmpty else { return nil }
        print("Profile image URL used: \(urlString)")
        // If the URL already contains a query (i.e., is a signed URL), do not append anything
        if urlString.contains("?") {
            return URL(string: urlString)
        }
        // Otherwise, append a cache-busting query
        let timestamp = user.updatedAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        let urlWithQuery = urlString + "?t=\(timestamp)"
        return URL(string: urlWithQuery)
    }

    var body: some View {
        ZStack {
            AsyncImage(url: cacheBustedProfileImageUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 40))
                    )
            }
            .clipShape(Circle())
            .frame(width: size, height: size)

            if isLoading {
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            }

            if isEditable && onDeleteTap != nil && user.profileImageUrl != nil {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            onDeleteTap?()
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                    }
                    Spacer()
                }
                .frame(width: size, height: size)
            }
        }
        .onTapGesture {
            if isEditable {
                onImageTap?()
            }
        }
    }

    // MARK: - Helper Methods

    private func compressProfileImage(_ image: UIImage) async -> UIImage? {
        return await MediaCompressionService.shared.compressImage(
            image,
            maxFileSize: 500_000, // 500KB
            quality: 0.8
        )
    }
}
