import SwiftUI

struct EmailSignInFormView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack {
            LargeRoundedTextView(label: "Sign In with Email")
                .padding(.top, 40)
                .padding(.bottom, 32)
            StyledTextField(
                placeholder: "Email or username",
                text: $email)
                .accessibilityIdentifier("Email or username")
                .padding(.bottom, 12)
            StyledTextField(
                placeholder: "Password",
                text: $password,
                isSecure: true
            )
                .accessibilityIdentifier("Password")
                .padding(.bottom, 12)
            LoadingButton(
                title: "Sign In",
                isLoading: false
            ) {
                Task {
                    await viewModel.signInClerk(email: email, password: password)
                    dismiss()
                }
            }
            .accessibilityIdentifier("Sign In")

            Spacer()
        }
        .padding(.horizontal, 24)
        .tint(.primary)
        .onAppear { viewModel.clearErrors() }
    }
}
