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
            }
        }
    }
}
