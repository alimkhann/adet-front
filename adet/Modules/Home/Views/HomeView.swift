import SwiftUI
import OSLog

struct HomeView: View {
    private let logger = Logger(subsystem: "com.adet.home", category: "HomeView")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Welcome to ädet")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)

                    Text("Your AI-powered habit tracking companion")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // TODO: Add dashboard content here
                    VStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Dashboard content coming soon")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Home")
            .onAppear {
                logger.info("HomeView appeared")
            }
        }
    }
}

#Preview {
    HomeView()
}
