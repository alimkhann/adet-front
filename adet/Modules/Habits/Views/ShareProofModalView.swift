import SwiftUI
import Kingfisher
import Combine

struct ShareProofModalView: View {
    let task: TaskEntry
    let proof: HabitProofState
    let post: Post?
    let freshProofUrl: String? // new parameter
    let onShareSuccess: () -> Void // New closure to notify parent of success
    let closeFriendsCount: Int
    @State private var description: String = ""
    @State private var selectedVisibility: String = "Friends"
    @State private var proofInputType: ProofInputType = .photo
    @State private var textProof: String? = nil
    @State private var lastDebuggedUrl: String? = nil // Track last printed URL
    @State private var showShareAlert = false
    @State private var isSharing = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @EnvironmentObject var postsViewModel: PostsViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel

    private func debugPrintOnce(for urlString: String, label: String) {
        if lastDebuggedUrl != urlString {
            print("[DEBUG] ShareProofModalView: \(label) \(urlString)")
            lastDebuggedUrl = urlString
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Share")
                .font(.title2).bold()
                .padding(.top, 8)

            OutlinedBox {
                Text(task.taskDescription ?? "No description")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            proofPreview

            TextField("Share your thoughts...", text: $description)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

            Text("Who can see this?")
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button(action: { selectedVisibility = "Friends" }) {
                    Text("Friends")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(selectedVisibility == "Friends" ? Color.black : Color.white)
                        .foregroundColor(selectedVisibility == "Friends" ? .white : .black)
                        .cornerRadius(10)
                }
                Button(action: { selectedVisibility = "Close Friends" }) {
                    Text("Close Friends")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(selectedVisibility == "Close Friends" ? Color.black.opacity(closeFriendsCount > 0 ? 1.0 : 0.2) : Color.white)
                        .foregroundColor(selectedVisibility == "Close Friends" ? .white : .black)
                        .cornerRadius(10)
                }
                .disabled(closeFriendsCount == 0)
            }

            Button(action: {
                showShareAlert = true
            }) {
                if isSharing {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Text("Share")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 8)
            .disabled(isSharing)
            .alert("Are you sure?", isPresented: $showShareAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Share", role: .destructive) { sharePost() }
            } message: {
                Text("You won't be able to edit/delete this post after sharing. Continue?")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .padding()
    }

    private func sharePost() {
        guard let post = post else {
            errorMessage = "No post found to share."
            showErrorAlert = true
            return
        }
        isSharing = true
        let privacy: PostPrivacy = (selectedVisibility == "Close Friends") ? .closeFriends : .friends
        let update = PostUpdate(description: description, privacy: privacy)
        Task {
            do {
                let response = try await PostService.shared.updatePost(id: post.id, updateData: update)
                if response.success {
                    // Refresh feed and profile post count
                    await postsViewModel.refreshFeed()
                    await postsViewModel.loadPersonalPosts()
                    await profileViewModel.refreshPostCount()
                    isSharing = false
                    onShareSuccess()
                } else {
                    errorMessage = response.message
                    showErrorAlert = true
                    isSharing = false
                }
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
                isSharing = false
            }
        }
    }

    @ViewBuilder
    private var proofPreview: some View {
        // Prefer freshProofUrl if available
        if let urlString = freshProofUrl, let url = URL(string: urlString), !urlString.isEmpty {
            VStack {
                KFImage.url(url)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 8)
                    .padding(.vertical, 8)
                    .onAppear {
                        debugPrintOnce(for: urlString, label: "Using freshProofUrl for image preview:")
                    }
                Text("Image preview")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else if let urlString = post?.proofUrls.first, let url = URL(string: urlString), !urlString.isEmpty {
            VStack {
                KFImage.url(url)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 8)
                    .padding(.vertical, 8)
                    .onAppear {
                        debugPrintOnce(for: urlString, label: "Using post.proofUrls[0] for image preview:")
                    }
                Text("Image preview")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else if let type = task.proofType?.lowercased(), (type == "photo" || type == "image"),
                  let urlString = task.proofContent, let url = URL(string: urlString), !urlString.isEmpty {
            VStack {
                KFImage.url(url)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(radius: 8)
                    .padding(.vertical, 8)
                    .onAppear {
                        debugPrintOnce(for: urlString, label: "Using task.proofContent for image preview:")
                    }
                Text("Image preview (from task)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else if case let .readyToSubmit(.image(imageData)) = proof {
            if let uiImage = UIImage(data: imageData) {
                VStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 220, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(radius: 8)
                        .padding(.vertical, 8)
                        .onAppear {
                            debugPrintOnce(for: "local-image", label: "Using local image data for image preview")
                        }
                    Text("Image preview (local)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Could not load image preview.")
                    .foregroundColor(.red)
            }
        } else {
            Text("No proof preview available.")
                .foregroundColor(.secondary)
        }
    }
}

// Helper extension for proof type check
extension HabitProofState {
    var isImageOrPhoto: Bool {
        switch self {
        case .readyToSubmit(let proofData):
            if case .image = proofData { return true }
            return false
        default:
            // For .submitted, we assume if the task.proofContent is set and proofType is photo
            return true
        }
    }
}
