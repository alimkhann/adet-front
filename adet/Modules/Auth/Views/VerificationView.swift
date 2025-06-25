import SwiftUI

struct VerificationView: View {
    @StateObject private var viewModel = VerificationViewModel()
    @State private var verificationCode = ""

    var body: some View {
        VStack {
            Text("Verification Code")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 24)

            TextField("Enter Verification Code", text: $verificationCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .accessibilityIdentifier("Verification Code")
                .padding(.bottom, 12)

            LoadingButton(
                title: "Verify",
                isLoading: viewModel.isClerkVerifying
            ) {
                Task { await viewModel.verifyClerk(verificationCode) }
            }
            .accessibilityIdentifier("Verify")
            .disabled(verificationCode.isEmpty)
            .padding(.horizontal, 24)

            Spacer()
        }
        .onAppear {
            viewModel.clearErrors()
        }
    }
}

struct VerificationView_Previews: PreviewProvider {
    static var previews: some View {
        VerificationView()
    }
}