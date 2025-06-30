import SwiftUI
import OSLog

struct MessageConversationView: View {
    let friendUser: UserBasic
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var conversation: Conversation?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let logger = Logger(subsystem: "com.adet.chats", category: "MessageConversationView")

    var body: some View {
        Group {
            if isLoading {
                // Loading state
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading conversation...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
            } else if let conversation = conversation {
                // Show chat detail view
                ChatDetailView(conversation: conversation)
                    .environmentObject(authViewModel)
            } else {
                // Error state
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text("Unable to Start Conversation")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(errorMessage ?? "Something went wrong while trying to start the conversation.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button("Try Again") {
                        Task {
                            await loadOrCreateConversation()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
                }
            }
        }
        .navigationBarHidden(conversation != nil) // Hide navigation bar when showing chat
        .task {
            await loadOrCreateConversation()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil && !isLoading)) {
            Button("OK") {
                errorMessage = nil
                dismiss()
            }
            Button("Retry") {
                Task {
                    await loadOrCreateConversation()
                }
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Helper Methods

    private func loadOrCreateConversation() async {
        logger.info("Loading or creating conversation with user \(friendUser.id)")
        isLoading = true
        errorMessage = nil

        do {
            // Use the shared ChatAPIService instance
            let chatService = ChatAPIService.shared

            // First, try to get existing conversations and find one with this friend
            let existingConversations = try await chatService.getConversations()

            if let existingConversation = existingConversations.first(where: {
                $0.otherParticipant.id == friendUser.id
            }) {
                // Found existing conversation
                logger.info("Found existing conversation \(existingConversation.id)")
                conversation = existingConversation
            } else {
                // Create new conversation
                logger.info("Creating new conversation with user \(friendUser.id)")
                let newConversation = try await chatService.createConversation(with: friendUser.id)
                conversation = newConversation
            }

            isLoading = false
        } catch {
            logger.error("Failed to load or create conversation: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        MessageConversationView(
            friendUser: UserBasic(
                id: 2,
                username: "sarah_wellness",
                name: "Sarah Johnson",
                bio: nil,
                profileImageUrl: nil
            )
        )
        .environmentObject(AuthViewModel())
    }
}