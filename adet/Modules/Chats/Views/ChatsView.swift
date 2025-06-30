import SwiftUI
import OSLog

struct ChatsView: View {
    private let logger = Logger(subsystem: "com.adet.chats", category: "ChatsView")

    var body: some View {
        ChatsListView()
            .onAppear {
                logger.info("ChatsView appeared")
            }
    }
}

#Preview {
    ChatsView()
}
