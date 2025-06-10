import SwiftUI

struct ErrorMessageView: View {
    let message: String?

    var body: some View {
        if let message = message {
            Text(message)
                .foregroundColor(.red)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .transition(.opacity)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ErrorMessageView(message: "Invalid email or password")
        ErrorMessageView(message: nil)
    }
    .padding()
}