import SwiftUI

struct ErrorMessageView: View {
    let message: String?
    let timeout: TimeInterval
    @State private var isVisible = false

    init(message: String?, timeout: TimeInterval = 3.0) {
        self.message = message
        self.timeout = timeout
    }

    var body: some View {
        if let message = message, !message.isEmpty {
            Text(message)
                .foregroundColor(.red)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .opacity(isVisible ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.3), value: isVisible)
                .onAppear {
                    // Reset state and show error
                    isVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isVisible = true
                        startTimeout()
                    }
                }
        }
    }

    private func startTimeout() {
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = false
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ErrorMessageView(message: "Invalid email or password")
        ErrorMessageView(message: "Network error occurred", timeout: 5.0)
        ErrorMessageView(message: nil)
    }
    .padding()
}