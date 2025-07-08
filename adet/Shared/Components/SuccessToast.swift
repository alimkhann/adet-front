import SwiftUI

struct SuccessToast: View {
    let message: String
    let onShare: (() -> Void)?
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isVisible = false

    init(message: String, onShare: (() -> Void)? = nil, onDismiss: @escaping () -> Void) {
        self.message = message
        self.onShare = onShare
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            // Dismiss button at top right
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }

            // Checkmark icon and encouragement
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.black)
                Text("Hell yeah, you crushed it!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Text(message)
                    .font(.body)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, -16)

            Spacer(minLength: 8)

            // Share button at the bottom
            if let onShare = onShare {
                Button(action: onShare) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share with others")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .scaleEffect(isVisible ? 1.0 : 0.95)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: isVisible)
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SuccessToast(
            message: "Task completed successfully! Great job putting on your running shoes.",
            onShare: {
                print("Share tapped")
            },
            onDismiss: {
                print("Dismiss tapped")
            }
        )

        SuccessToast(
            message: "Simple success message without sharing.",
            onDismiss: {
                print("Dismiss tapped")
            }
        )
    }
    .padding()
}