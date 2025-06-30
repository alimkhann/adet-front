import SwiftUI
import OSLog

struct FriendsView: View {
    @StateObject private var viewModel = FriendsViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @FocusState private var isSearchFocused: Bool

    private let logger = Logger(subsystem: "com.adet.friends", category: "FriendsView")

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Always-visible search bar
                searchBar

                // Tab structure below search
                if viewModel.shouldShowSearchResults {
                    // Show search results when searching
                    searchResultsView
                } else {
                    // Show normal tab content
                    tabContentView
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                logger.info("FriendsView appeared")
                Task {
                    await viewModel.loadAllData()
                }
            }
            .refreshable {
                await viewModel.loadAllData()
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search by username", text: $viewModel.searchQuery)
                    .focused($isSearchFocused)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onTapGesture {
                        viewModel.setSearchActive(true)
                    }
                    .onChange(of: viewModel.searchQuery) { _, newValue in
                        if !newValue.isEmpty {
                            viewModel.setSearchActive(true)
                        }
                    }

                if viewModel.isSearchActive {
                    Button("Cancel") {
                        viewModel.clearSearch()
                        isSearchFocused = false
                    }
                    .foregroundColor(.accentColor)
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

    // MARK: - Tab Content

    private var tabContentView: some View {
        VStack(spacing: 0) {
            // Tab buttons
            HStack(spacing: 0) {
                TabButton(
                    title: "Friends",
                    count: viewModel.friendsCount,
                    isSelected: viewModel.selectedTab == 0
                ) {
                    viewModel.selectedTab = 0
                }

                TabButton(
                    title: "Requests",
                    count: viewModel.incomingRequestsCount,
                    isSelected: viewModel.selectedTab == 1
                ) {
                    viewModel.selectedTab = 1
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)

            Divider()
                .padding(.top, 12)

            // Tab content
            TabView(selection: $viewModel.selectedTab) {
                friendsListView
                    .tag(0)

                friendRequestsView
                    .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }

    // MARK: - Friends List

    private var friendsListView: some View {
        Group {
            if viewModel.isLoadingFriends {
                ProgressView("Loading friends...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.hasAnyFriends {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.friends) { friend in
                            FriendCardView(
                                friend: friend,
                                isRemoving: viewModel.isRemovingFriend(friend.friendId),
                                onRemove: {
                                    Task {
                                        await viewModel.removeFriend(friend)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
            } else {
                EmptyFriendsView()
            }
        }
    }

    // MARK: - Friend Requests

    private var friendRequestsView: some View {
        Group {
            if viewModel.isLoadingRequests {
                ProgressView("Loading requests...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.hasIncomingRequests || viewModel.hasOutgoingRequests {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Incoming requests
                        if viewModel.hasIncomingRequests {
                            requestsSection(
                                title: "Incoming Requests",
                                requests: viewModel.incomingRequests,
                                isIncoming: true
                            )
                        }

                        // Outgoing requests
                        if viewModel.hasOutgoingRequests {
                            requestsSection(
                                title: "Sent Requests",
                                requests: viewModel.outgoingRequests,
                                isIncoming: false
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
            } else {
                EmptyRequestsView()
            }
        }
    }

    private func requestsSection(title: String, requests: [FriendRequest], isIncoming: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(requests.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }

            ForEach(requests) { request in
                FriendRequestCardView(
                    request: request,
                    isIncoming: isIncoming,
                    isProcessing: viewModel.isProcessingRequest(request.id),
                    onAccept: {
                        Task {
                            await viewModel.acceptFriendRequest(request)
                        }
                    },
                    onDecline: {
                        Task {
                            await viewModel.declineFriendRequest(request)
                        }
                    },
                    onCancel: {
                        Task {
                            await viewModel.cancelFriendRequest(request)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        Group {
            if viewModel.isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.hasSearchResults {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.searchResults) { user in
                            UserSearchCardView(
                                user: user,
                                onAddFriend: {
                                    Task {
                                        await viewModel.sendFriendRequest(to: user)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
            } else if !viewModel.searchQuery.isEmpty {
                EmptySearchView(query: viewModel.searchQuery)
            } else {
                EmptySearchView(query: "")
            }
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .medium)

                    if count > 0 {
                        Text("\(count)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                    }
                }
                .foregroundColor(isSelected ? .primary : .secondary)

                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(isSelected ? .accentColor : .clear)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    FriendsView()
        .environmentObject(AuthViewModel())
}
