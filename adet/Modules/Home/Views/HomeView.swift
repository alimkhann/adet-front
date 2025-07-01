import SwiftUI
import OSLog

struct HomeView: View {
    private let logger = Logger(subsystem: "com.adet.home", category: "HomeView")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer()
                        .frame(height: 200)
                    
                    Image(systemName: "wind")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.gray)
                    
                    Text("It is a bit quiet here.")
                    
                    Text("Start posting and find friends to see content!")

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("ädet")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                logger.info("HomeView appeared")
            }
        }
    }
}

#Preview {
    HomeView()
}
