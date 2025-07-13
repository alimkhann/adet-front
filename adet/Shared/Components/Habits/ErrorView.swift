import SwiftUI

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Error").font(.title2).fontWeight(.bold).foregroundColor(.red)
            Text(message).multilineTextAlignment(.center)
            Button {
                onRetry()
            } label: {
                Text("Retry")
                    .frame(minHeight: 44)
            }
            .buttonStyle(PrimaryButtonStyle())
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}