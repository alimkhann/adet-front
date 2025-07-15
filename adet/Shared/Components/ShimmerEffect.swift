import SwiftUI

// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: isAnimating ? 200 : -200)
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                    .onAppear {
                        isAnimating = true
                    }
                    .clipped()
            )
            .clipped()
    }
}

// MARK: - Shimmer Card Components

struct ShimmerFriendCard: View {
    var body: some View {
        HStack(spacing: 16) {
            // Profile Image Placeholder
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .modifier(ShimmerEffect())

            VStack(alignment: .leading, spacing: 8) {
                // Name placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
                    .frame(maxWidth: 120)
                    .cornerRadius(8)
                    .modifier(ShimmerEffect())

                // Username placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 12)
                    .frame(maxWidth: 80)
                    .cornerRadius(6)
                    .modifier(ShimmerEffect())
            }

            Spacer()

            // Button placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 32, height: 32)
                .cornerRadius(8)
                .modifier(ShimmerEffect())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct ShimmerRequestCard: View {
    var body: some View {
        HStack(spacing: 16) {
            // Profile Image Placeholder
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .modifier(ShimmerEffect())

            VStack(alignment: .leading, spacing: 8) {
                // Name placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
                    .frame(maxWidth: 120)
                    .cornerRadius(8)
                    .modifier(ShimmerEffect())

                // Status placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 12)
                    .frame(maxWidth: 90)
                    .cornerRadius(6)
                    .modifier(ShimmerEffect())
            }

            Spacer()

            // Action buttons placeholder
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)
                    .modifier(ShimmerEffect())

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)
                    .modifier(ShimmerEffect())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Shimmer Views

struct ShimmerFriendsListView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    ShimmerFriendCard()
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
    }
}

struct ShimmerRequestsListView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    ShimmerRequestCard()
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
    }
}

// MARK: - Shimmer Posts List View

struct ShimmerPostsListView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { _ in
                    ShimmerPostCard()
                }
            }
            .padding(.horizontal)
            .padding(.top, 24)
        }
    }
}

struct ShimmerPostCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header (profile image + name)
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .modifier(ShimmerEffect())
                VStack(alignment: .leading, spacing: 6) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 14)
                        .frame(maxWidth: 100)
                        .cornerRadius(7)
                        .modifier(ShimmerEffect())
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 10)
                        .frame(maxWidth: 60)
                        .cornerRadius(5)
                        .modifier(ShimmerEffect())
                }
                Spacer()
            }
            // Post content
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 80)
                .cornerRadius(10)
                .modifier(ShimmerEffect())
            // Footer (like/comment/share)
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .cornerRadius(6)
                        .modifier(ShimmerEffect())
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Shimmer Habits List View

struct ShimmerHabitsListView: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    ShimmerHabitCard()
                }
            }
            .padding(.horizontal)
            .padding(.top, 24)
        }
        .frame(height: 120)
    }
}

struct ShimmerHabitCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 100, height: 18)
                .cornerRadius(8)
                .modifier(ShimmerEffect())
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 80, height: 12)
                .cornerRadius(6)
                .modifier(ShimmerEffect())
            Spacer()
        }
        .frame(width: 150, height: 100)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

// MARK: - View Extension

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerEffect())
    }
}