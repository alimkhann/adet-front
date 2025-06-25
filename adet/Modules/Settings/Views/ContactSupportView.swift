import SwiftUI
import OSLog

struct ContactSupportView: View {
    private let logger = Logger(subsystem: "com.adet.settings", category: "ContactSupportView")

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "headphones")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding(.top, 40)

                Text("Contact Support")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Need help? We're here for you!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 16) {
                    Button(action: {
                        logger.info("User tapped email support")
                        // TODO: Open email client
                    }) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Email Support")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button(action: {
                        logger.info("User tapped chat support")
                        // TODO: Open in-app chat
                    }) {
                        HStack {
                            Image(systemName: "message")
                            Text("Live Chat")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("Support")
            .onAppear {
                logger.info("ContactSupportView appeared")
            }
        }
    }
}