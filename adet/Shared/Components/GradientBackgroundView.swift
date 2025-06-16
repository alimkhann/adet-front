import SwiftUI

struct GradientBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var colors: [Color] {
        switch colorScheme {
        case .light:
            return [Color(.white), Color(.lightGray)]
        case .dark:
            return [Color.black, Color(.darkGray)]
        @unknown default:
            return [Color.white, Color(.lightGray)]
        }
    }

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    GradientBackgroundView()
}
