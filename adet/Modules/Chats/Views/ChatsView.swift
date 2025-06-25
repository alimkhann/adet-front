import SwiftUI
import OSLog

struct ChatsView: View {
    private let logger = Logger(subsystem: "com.adet.chats", category: "ChatsView")

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                    .padding(.top, 40)

                Text("AI Chat & Support")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Get personalized advice, motivation, and support from your AI habit coach. Ask questions, share challenges, and receive guidance.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // TODO: Implement AI chat functionality
                Text("Coming Soon")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 20)

                Spacer()
            }
            .navigationTitle("AI Chat")
            .onAppear {
                logger.info("ChatsView appeared")
            }
        }
    }
}

#Preview {
    ChatsView()
}
