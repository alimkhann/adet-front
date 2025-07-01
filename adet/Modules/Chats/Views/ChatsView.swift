import SwiftUI
import OSLog

struct ChatsView: View {
    @StateObject private var viewModel = ChatsListViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedConversation: Conversation?
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private let logger = Logger(subsystem: "com.adet.chats", category: "ChatsView")

    // Computed property to avoid async autoclosure issues
    private var showingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    // Filtered conversations based on search
    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return viewModel.conversations
        } else {
            return viewModel.conversations.filter { conversation in
                conversation.otherParticipant.displayName.localizedCaseInsensitiveContains(searchText) ||
                (conversation.otherParticipant.username?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                    .background(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)

                // Content
                Group {
                    if viewModel.isLoading && viewModel.conversations.isEmpty {
                        // Initial loading state
                        VStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading conversations...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                            Spacer()
                        }
                    } else if viewModel.conversations.isEmpty {
                        // Empty state
                        EmptyChatsView()
                    } else {
                        // Conversations list
                        conversationsList
                    }
                }
                .background(Color(.systemGroupedBackground))
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.refreshConversations()
            }
            .task {
                #if DEBUG
                // For development, load mock data first
                if viewModel.conversations.isEmpty {
                    viewModel.loadMockConversations()
                }
                #endif
                await viewModel.loadConversations()
            }
            .alert("Error", isPresented: showingError) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .navigationDestination(item: $selectedConversation) { conversation in
                ChatDetailView(conversation: conversation)
                    .environmentObject(authViewModel)
            }
            .onAppear {
                logger.info("ChatsView appeared")
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search conversations", text: $searchText)
                    .focused($isSearchFocused)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                        isSearchFocused = false
                    }
                    .foregroundColor(.accentColor)
                    .font(.subheadline)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 8)

            Divider()
                .padding(.top, 12)
        }
    }

    // MARK: - Conversations List

    private var conversationsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredConversations) { conversation in
                    ConversationCardView(
                        conversation: conversation,
                        onTap: {
                            selectedConversation = conversation
                            logger.info("Selected conversation \(conversation.id) with \(conversation.otherParticipant.displayName)")
                        }
                    )
                    .environmentObject(authViewModel)
                    .onAppear {
                        // Load more conversations when approaching the end
                        if conversation.id == viewModel.conversations.last?.id {
                            Task {
                                await viewModel.loadMoreConversations()
                            }
                        }
                    }
                }

                // Loading more indicator
                if viewModel.isLoading && !viewModel.conversations.isEmpty {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }
}

#Preview {
    ChatsView()
}
