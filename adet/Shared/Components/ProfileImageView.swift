import SwiftUI
import Kingfisher

struct AuthModifier: ImageDownloadRequestModifier {
    let token: String
    func modified(for request: URLRequest) -> URLRequest? {
        var req = request
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return req
    }
}

struct ProfileImageView: View {
    let user: User?
    let size: CGFloat
    let isEditable: Bool
    let onImageTap: (() -> Void)?
    let onDeleteTap: (() -> Void)?
    let jwtToken: String?

    @Environment(\.colorScheme) private var colorScheme

    init(user: User?, size: CGFloat = 80, isEditable: Bool = false, onImageTap: (() -> Void)? = nil, onDeleteTap: (() -> Void)? = nil, jwtToken: String?) {
        self.user = user
        self.size = size
        self.isEditable = isEditable
        self.onImageTap = onImageTap
        self.onDeleteTap = onDeleteTap
        self.jwtToken = jwtToken
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(colorScheme == .dark ? Color("Zinc900") : Color("Zinc100"))
                .frame(width: size, height: size)

            if let imageUrl = user?.profileImageUrl, !imageUrl.isEmpty {
                // Use backend proxy for Azure Blob Storage URLs
                let displayUrl: URL? = {
                    if imageUrl.contains("blob.core.windows.net") {
                        return URL(string: "http://localhost:8000/api/v1/users/me/profile-image/raw")
                    } else {
                        return URL(string: imageUrl)
                    }
                }()
                if let displayUrl = displayUrl, let jwtToken = jwtToken {
                    KFImage(displayUrl)
                        .requestModifier(AuthModifier(token: jwtToken))
                        .placeholder {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                                .scaleEffect(0.8)
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                }

                // Delete button overlay for editable mode
                if isEditable && onDeleteTap != nil {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { onDeleteTap?() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: size * 0.25))
                                    .foregroundColor(.red)
                                    .background(Color.white)
                                    .clipShape(Circle())
                            }
                        }
                        Spacer()
                    }
                    .frame(width: size, height: size)
                }
            } else {
                // Fallback to initials
                Text(userInitials)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundColor(.primary)

                // Camera icon for editable mode
                if isEditable {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "camera.fill")
                                .font(.system(size: size * 0.2))
                                .foregroundColor(.secondary)
                                .background(
                                    Circle()
                                        .fill(.background)
                                        .frame(width: size * 0.3, height: size * 0.3)
                                )
                        }
                    }
                    .frame(width: size, height: size)
                }
            }
        }
        .contentShape(Circle())
        .onTapGesture {
            if isEditable {
                onImageTap?()
            }
        }
    }

    private var userInitials: String {
        guard let user = user else { return "?" }

        let components = [user.username, user.email]
            .compactMap { $0 }
            .first?
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        if let components = components, !components.isEmpty {
            if components.count == 1 {
                // Single word - take first two characters
                let word = components[0]
                return String(word.prefix(2)).uppercased()
            } else {
                // Multiple words - take first character of first two words
                return components
                    .prefix(2)
                    .compactMap { $0.first }
                    .map { String($0) }
                    .joined()
                    .uppercased()
            }
        }

        // Fallback to first character of email
        return String(user.email.prefix(1)).uppercased()
    }
}

#Preview {
    VStack(spacing: 20) {
        ProfileImageView(
            user: User(
                id: 1,
                clerkId: "test",
                email: "john.doe@example.com",
                username: "johndoe",
                profileImageUrl: nil,
                isActive: true,
                createdAt: Date(),
                updatedAt: nil
            ),
            size: 80,
            isEditable: false,
            jwtToken: nil
        )

        ProfileImageView(
            user: User(
                id: 1,
                clerkId: "test",
                email: "john.doe@example.com",
                username: "johndoe",
                profileImageUrl: nil,
                isActive: true,
                createdAt: Date(),
                updatedAt: nil
            ),
            size: 80,
            isEditable: true,
            onImageTap: {},
            onDeleteTap: {},
            jwtToken: "testToken"
        )
    }
    .padding()
}
