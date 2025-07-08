import SwiftUI

struct BlockUserView: View {
    let user: UserBasic
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FriendsViewModel()
    @State private var showConfirmation = false
    @State private var isBlocking = false
    @AppStorage("appLanguage") var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // User Info
                VStack(spacing: 16) {
                    if let profileImageUrl = user.profileImageUrl {
                        AsyncImage(url: URL(string: profileImageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color(.systemGray5))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.secondary)
                                )
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 32))
                            )
                    }

                    VStack(spacing: 4) {
                        Text(user.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("@\(user.displayUsername)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Warning Message
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)

                    Text("block".t(appLanguage))
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Are you sure you want to block \(user.displayName)?")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Text("This will:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint(text: "Remove them from your friends list")
                        BulletPoint(text: "Prevent them from messaging you")
                        BulletPoint(text: "Hide their posts from your feed")
                        BulletPoint(text: "Prevent them from seeing your profile")
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Spacer()

                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        showConfirmation = true
                    }) {
                        HStack {
                            if isBlocking {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "person.crop.circle.badge.minus")
                            }

                            Text(isBlocking ? "Blocking..." : "Block User")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isBlocking)

                    Button("cancel".t(appLanguage)) {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("block".t(appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("cancel".t(appLanguage)) {
                        dismiss()
                    }
                }
            }
            .alert("block".t(appLanguage), isPresented: $showConfirmation) {
                Button("block".t(appLanguage), role: .destructive) {
                    Task {
                        await blockUser()
                    }
                }
                Button("cancel".t(appLanguage), role: .cancel) { }
            } message: {
                Text("This action cannot be undone. Are you sure you want to block \(user.displayName)?")
            }
        }
    }

    private func blockUser() async {
        isBlocking = true

        let success = await viewModel.blockUser(userId: user.id, reason: "User initiated block")

        await MainActor.run {
            isBlocking = false
            if success {
                dismiss()
            }
        }
    }
}

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.secondary)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

#Preview {
    BlockUserView(user: UserBasic(
        id: 1,
        username: "testuser",
        name: "Test User",
        bio: "Test bio",
        profileImageUrl: nil
    ))
}
