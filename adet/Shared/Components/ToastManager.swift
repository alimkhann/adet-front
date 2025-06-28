import SwiftUI

@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var currentToast: ToastData?

    private init() {}

    func showError(_ message: String) {
        show(message: message, type: .error)
    }

    func showSuccess(_ message: String) {
        show(message: message, type: .success)
    }

    func showInfo(_ message: String) {
        show(message: message, type: .info)
    }

    private func show(message: String, type: ToastType) {
        // Dismiss current toast if any
        currentToast = nil

        // Show new toast after a brief delay to ensure smooth animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.currentToast = ToastData(message: message, type: type)
        }
    }

    func dismiss() {
        currentToast = nil
    }
}

struct ToastData: Identifiable {
    let id = UUID()
    let message: String
    let type: ToastType
}

struct ToastOverlay: View {
    @StateObject private var toastManager = ToastManager.shared

    var body: some View {
        ZStack {
            if let toast = toastManager.currentToast {
                VStack {
                    ToastView(
                        message: toast.message,
                        type: toast.type,
                        onDismiss: {
                            toastManager.dismiss()
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .zIndex(1000)
                .allowsHitTesting(true)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: toastManager.currentToast?.id)
    }
}


