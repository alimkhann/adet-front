import Foundation
import Combine
import OSLog

@MainActor
class ChatsListViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.adet.chats", category: "ChatsListViewModel")
    private let chatAPIService = ChatAPIService.shared
    private var cancellables = Set<AnyCancellable>()

    // Published properties for UI
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var connectionState: ConnectionState = .disconnected

    // Pagination
    private var hasMoreConversations = true
    private let conversationsPerPage = 20

    init() {
        setupRealTimeUpdates()
    }

    // MARK: - Public Interface

    /// Loads conversations for the first time
    func loadConversations() async {
        guard !isLoading else { return }

        await setLoading(true)
        errorMessage = nil

        do {
            logger.info("Loading conversations")
            let loadedConversations = try await chatAPIService.getConversations(
                limit: conversationsPerPage,
                offset: 0
            )

            await MainActor.run {
                self.conversations = loadedConversations
                self.hasMoreConversations = loadedConversations.count >= self.conversationsPerPage
                self.isLoading = false
            }

            logger.info("Loaded \(loadedConversations.count) conversations")

        } catch {
            await handleError(error)
        }
    }

    /// Refreshes conversations (pull-to-refresh)
    func refreshConversations() async {
        guard !isRefreshing else { return }

        await setRefreshing(true)

        do {
            logger.info("Refreshing conversations")
            let refreshedConversations = try await chatAPIService.getConversations(
                limit: conversationsPerPage,
                offset: 0
            )

            await MainActor.run {
                self.conversations = refreshedConversations
                self.hasMoreConversations = refreshedConversations.count >= self.conversationsPerPage
                self.isRefreshing = false
                self.errorMessage = nil
            }

            logger.info("Refreshed \(refreshedConversations.count) conversations")

        } catch {
            await handleError(error)
            await setRefreshing(false)
        }
    }

    /// Loads more conversations (pagination)
    func loadMoreConversations() async {
        guard !isLoading && hasMoreConversations else { return }

        await setLoading(true)

        do {
            logger.info("Loading more conversations (offset: \(conversations.count))")
            let moreConversations = try await chatAPIService.getConversations(
                limit: conversationsPerPage,
                offset: conversations.count
            )

            await MainActor.run {
                self.conversations.append(contentsOf: moreConversations)
                self.hasMoreConversations = moreConversations.count >= self.conversationsPerPage
                self.isLoading = false
            }

            logger.info("Loaded \(moreConversations.count) more conversations")

        } catch {
            await handleError(error)
        }
    }

    /// Creates a new conversation with a friend
    func startConversation(with friendId: Int) async -> Conversation? {
        do {
            logger.info("Starting conversation with friend \(friendId)")
            let conversation = try await chatAPIService.createConversation(with: friendId)

            await MainActor.run {
                // Add to the beginning of the list if not already present
                if !self.conversations.contains(where: { $0.id == conversation.id }) {
                    self.conversations.insert(conversation, at: 0)
                }
            }

            logger.info("Created conversation \(conversation.id)")
            return conversation

        } catch {
            await handleError(error)
            return nil
        }
    }

    /// Deletes or clears conversation history
    func deleteConversation(_ conversation: Conversation) {
        // TODO: Implement conversation deletion when backend supports it
        logger.info("Conversation deletion not yet implemented")
    }

    // MARK: - Real-time Updates

    private func setupRealTimeUpdates() {
        // Listen for incoming messages to update conversation list
        chatAPIService.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleIncomingMessage(message)
            }
            .store(in: &cancellables)

        // Listen for connection state changes
        chatAPIService.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionState, on: self)
            .store(in: &cancellables)

        // Listen for presence updates
        chatAPIService.presencePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] presenceEvent in
                self?.handlePresenceUpdate(presenceEvent)
            }
            .store(in: &cancellables)
    }

    private func handleIncomingMessage(_ message: Message) {
        logger.debug("Received message for conversation \(message.conversationId)")

        // Find and update the conversation
        if let index = conversations.firstIndex(where: { $0.id == message.conversationId }) {
            var updatedConversation = conversations[index]

            // Update last message and timestamp
            updatedConversation = Conversation(
                id: updatedConversation.id,
                participant1Id: updatedConversation.participant1Id,
                participant2Id: updatedConversation.participant2Id,
                createdAt: updatedConversation.createdAt,
                updatedAt: updatedConversation.updatedAt,
                lastMessageAt: message.createdAt,
                otherParticipant: updatedConversation.otherParticipant,
                lastMessage: message,
                unreadCount: updatedConversation.unreadCount + 1, // Increment unread count
                isOtherOnline: updatedConversation.isOtherOnline,
                otherLastSeen: updatedConversation.otherLastSeen
            )

            // Move conversation to top and update
            conversations.remove(at: index)
            conversations.insert(updatedConversation, at: 0)
        }
    }

    private func handlePresenceUpdate(_ presenceEvent: PresenceEvent) {
        logger.debug("Received presence update for user \(presenceEvent.userId)")

        // Update online status for the relevant conversation
        if let index = conversations.firstIndex(where: {
            $0.otherParticipant.id == presenceEvent.userId
        }) {
            var updatedConversation = conversations[index]

            updatedConversation = Conversation(
                id: updatedConversation.id,
                participant1Id: updatedConversation.participant1Id,
                participant2Id: updatedConversation.participant2Id,
                createdAt: updatedConversation.createdAt,
                updatedAt: updatedConversation.updatedAt,
                lastMessageAt: updatedConversation.lastMessageAt,
                otherParticipant: updatedConversation.otherParticipant,
                lastMessage: updatedConversation.lastMessage,
                unreadCount: updatedConversation.unreadCount,
                isOtherOnline: presenceEvent.isOnline,
                otherLastSeen: presenceEvent.lastSeen
            )

            conversations[index] = updatedConversation
        }
    }

    // MARK: - Helper Methods

    private func setLoading(_ loading: Bool) async {
        await MainActor.run {
            self.isLoading = loading
        }
    }

    private func setRefreshing(_ refreshing: Bool) async {
        await MainActor.run {
            self.isRefreshing = refreshing
        }
    }

    private func handleError(_ error: Error) async {
        let chatError = chatAPIService.handleChatError(error)

        await MainActor.run {
            self.errorMessage = chatError.localizedDescription
            self.isLoading = false
            self.isRefreshing = false
        }

        logger.error("Chat list error: \(chatError.localizedDescription)")
    }

    // MARK: - Computed Properties

    var hasConversations: Bool {
        !conversations.isEmpty
    }

    var totalUnreadCount: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    var onlineFriendsCount: Int {
        conversations.filter { $0.isOtherOnline }.count
    }

    // MARK: - View Helpers

    func lastMessagePreview(for conversation: Conversation) -> String {
        guard let lastMessage = conversation.lastMessage else {
            return "No messages yet"
        }

        let preview = lastMessage.content.prefix(50)
        return preview.count < lastMessage.content.count ? "\(preview)..." : String(preview)
    }

    func timeAgo(for conversation: Conversation) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated

        if let lastMessage = conversation.lastMessage {
            return formatter.localizedString(for: lastMessage.createdAt, relativeTo: Date())
        } else {
            return formatter.localizedString(for: conversation.createdAt, relativeTo: Date())
        }
    }

    func shouldShowUnreadBadge(for conversation: Conversation) -> Bool {
        conversation.unreadCount > 0
    }

    func onlineStatusText(for conversation: Conversation) -> String {
        if conversation.isOtherOnline {
            return "Online"
        } else if let lastSeen = conversation.otherLastSeen {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return "Last seen \(formatter.localizedString(for: lastSeen, relativeTo: Date()))"
        } else {
            return "Offline"
        }
    }
}

// MARK: - Development Helpers

#if DEBUG
extension ChatsListViewModel {
    /// Creates mock conversations for development/testing
    func loadMockConversations() {
        conversations = [
            Conversation(
                id: 1,
                participant1Id: 1,
                participant2Id: 2,
                createdAt: Date().addingTimeInterval(-86400),
                updatedAt: Date(),
                lastMessageAt: Date().addingTimeInterval(-3600),
                otherParticipant: UserBasic(
                    id: 2,
                    username: "sarah_wellness",
                    name: "Sarah Johnson",
                    profileImageUrl: nil
                ),
                lastMessage: Message(
                    id: 101,
                    conversationId: 1,
                    senderId: 2,
                    content: "How's your morning routine going?",
                    messageType: "text",
                    status: .read,
                    createdAt: Date().addingTimeInterval(-3600),
                    deliveredAt: Date().addingTimeInterval(-3590),
                    readAt: Date().addingTimeInterval(-3580),
                    sender: UserBasic(id: 2, username: "sarah_wellness", name: "Sarah Johnson", profileImageUrl: nil)
                ),
                unreadCount: 0,
                isOtherOnline: true,
                otherLastSeen: nil
            ),
            Conversation(
                id: 2,
                participant1Id: 1,
                participant2Id: 3,
                createdAt: Date().addingTimeInterval(-172800),
                updatedAt: Date(),
                lastMessageAt: Date().addingTimeInterval(-7200),
                otherParticipant: UserBasic(
                    id: 3,
                    username: "mike_fitness",
                    name: "Mike Chen",
                    profileImageUrl: nil
                ),
                lastMessage: Message(
                    id: 102,
                    conversationId: 2,
                    senderId: 3,
                    content: "Great job on completing your workout streak! 💪",
                    messageType: "text",
                    status: .delivered,
                    createdAt: Date().addingTimeInterval(-7200),
                    deliveredAt: Date().addingTimeInterval(-7190),
                    readAt: nil,
                    sender: UserBasic(id: 3, username: "mike_fitness", name: "Mike Chen", profileImageUrl: nil)
                ),
                unreadCount: 1,
                isOtherOnline: false,
                otherLastSeen: Date().addingTimeInterval(-1800)
            )
        ]
    }
}
#endif