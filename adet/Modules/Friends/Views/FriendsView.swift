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
                    .background(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)

                // Tab structure below search
                if viewModel.shouldShowSearchResults {
                    // Show search results when searching
                    searchResultsView
                        .background(Color(.systemGroupedBackground))
                } else {
                    // Show normal tab content
                    tabContentView
                        .background(Color(.systemGroupedBackground))
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: CloseFriendsManagementView().environmentObject(authViewModel)) {
                        Image(systemName: "person.2.circle")
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
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
                            // Trigger search with a small delay to avoid too many API calls
                            Task {
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                                await viewModel.searchUsers()
                            }
                        } else {
                            viewModel.clearSearch()
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
                    count: 0,
                    isSelected: viewModel.selectedTab == 0
                ) {
                    HapticManager.shared.selection()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedTab = 0
                    }
                }

                TabButton(
                    title: "Requests",
                    count: viewModel.incomingRequestsCount,
                    isSelected: viewModel.selectedTab == 1
                ) {
                    HapticManager.shared.selection()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedTab = 1
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .background(Color(.systemBackground))

            Divider()

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
        VStack(spacing: 0) {
            // Friend count text
            if !viewModel.isLoadingFriends {
                HStack {
                    Text(friendCountText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    Spacer()
                }
            }

            // Friends content
            Group {
                if viewModel.isLoadingFriends {
                    ShimmerFriendsListView()
                } else if viewModel.hasAnyFriends {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(viewModel.friends.enumerated()), id: \.element.id) { index, friend in
                                FriendCardView(
                                    friend: friend,
                                    isRemoving: viewModel.isRemovingFriend(friend.friendId),
                                    onRemove: {
                                        Task {
                                            await viewModel.removeFriend(friend)
                                        }
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                                .animation(.easeInOut(duration: 0.3).delay(Double(index) * 0.05), value: viewModel.friends.count)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    }
                } else {
                    EmptyFriendsView()
                }
            }
        }
    }

    // MARK: - Friend Requests

    private var friendRequestsView: some View {
        Group {
            if viewModel.isLoadingRequests {
                ShimmerRequestsListView()
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
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Searching...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.hasSearchResults {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, user in
                            UserSearchCardView(
                                user: user,
                                onAddFriend: {
                                    Task {
                                        await viewModel.sendFriendRequest(to: user)
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                            .animation(.easeInOut(duration: 0.3).delay(Double(index) * 0.05), value: viewModel.searchResults.count)
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

    // MARK: - Helper Properties

    private var friendCountText: String {
        let count = viewModel.friendsCount
        return count == 1 ? "1 friend" : "\(count) friends"
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
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .medium)

                    if count > 0 {
                        Text("\(count)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(
                                Circle()
                                    .fill(isSelected ? Color.accentColor : Color.red)
                            )
                            .scaleEffect(isSelected ? 1.0 : 0.9)
                    }
                }
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(.vertical, 8)

                Rectangle()
                    .frame(height: isSelected ? 2 : 1)
                    .foregroundColor(isSelected ? .accentColor : .clear)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    FriendsView()
        .environmentObject(AuthViewModel())
}
