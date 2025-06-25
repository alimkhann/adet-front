import SwiftUI
import OSLog

struct FriendsView: View {
    private let logger = Logger(subsystem: "com.adet.friends", category: "FriendsView")

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.2")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                    .padding(.top, 40)

                Text("Friends & Social")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Connect with friends, share your progress, and motivate each other to build better habits together.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // TODO: Implement friends functionality
                Text("Coming Soon")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 20)

                Spacer()
            }
            .navigationTitle("Friends")
            .onAppear {
                logger.info("FriendsView appeared")
            }
        }
    }
}

#Preview {
    FriendsView()
}
