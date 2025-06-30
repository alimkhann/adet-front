import SwiftUI

enum ToastType {
    case error
    case success
    case info

    var backgroundColor: Color {
        switch self {
        case .error: return .red
        case .success: return .green
        case .info: return .blue
        }
    }

    var icon: String {
        switch self {
        case .error: return "xmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

struct ToastView: View {
    let message: String
    let type: ToastType
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var workItem: DispatchWorkItem?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .semibold))

            Text(message)
                .foregroundColor(.white)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            Spacer()

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(type.backgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .offset(y: isVisible ? 0 : -100)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            show()
        }
        .onTapGesture {
            dismiss()
        }
    }

    private func show() {
        isVisible = true
        scheduleAutoDismiss()
    }

    private func dismiss() {
        workItem?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onDismiss()
        }
    }

    private func scheduleAutoDismiss() {
        workItem?.cancel()
        let newWorkItem = DispatchWorkItem {
            dismiss()
        }
        workItem = newWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: newWorkItem)
    }
}

#Preview {
    VStack(spacing: 20) {
        ToastView(message: "Invalid email or password", type: .error) {}
        ToastView(message: "Profile updated successfully!", type: .success) {}
        ToastView(message: "This is an info message", type: .info) {}
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemBackground))
}





