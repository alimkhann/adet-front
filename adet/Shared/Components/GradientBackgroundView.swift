import SwiftUI

struct GradientBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [Color(.black), Color(.darkGray)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    GradientBackgroundView()
}