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

    var body: some View {
        ZStack {
            AsyncImage(url: URL(string: user.profileImageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: size * 0.4))
                    )
            }
            .frame(width: size, height: size)
            .clipShape(Circle())

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

#Preview {
    ProfileImageView(
        user: User(
            id: 1,
            clerkId: "test",
            email: "test@example.com",
            name: "Test User",
            username: "testuser",
            bio: "Test bio",
            profileImageUrl: nil,
            isActive: true,
            createdAt: Date(),
            updatedAt: nil
        ),
        size: 60,
        isEditable: true,
        onImageTap: nil,
        onDeleteTap: nil,
        jwtToken: nil
    )
}