import SwiftUI

struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity, minHeight: 48)
            } else {
                Text(title)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isLoading)
    }
}

#Preview {
    VStack(spacing: 20) {
        LoadingButton(title: "Sign In", isLoading: false) {}
        LoadingButton(title: "Sign In", isLoading: true) {}
    }
    .padding()
}