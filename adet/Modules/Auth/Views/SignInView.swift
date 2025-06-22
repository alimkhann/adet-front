import SwiftUI

struct SignInView: View {
    @EnvironmentObject var viewModel: AuthViewModel

    @State private var email     = ""
    @State private var password  = ""

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackgroundView()

                VStack {
                    LargeRoundedTextView(label: "Sign Into Account")
                        .padding(.top, 40)
                        .padding(.bottom, 32)

                    Group {
                        StyledTextField(
                            placeholder: "Email",
                            text: $email)
                        .accessibilityIdentifier("Email")
                        .padding(.bottom, 12)

                        StyledTextField(
                            placeholder: "Password",
                            text: $password,
                            isSecure: true
                        )
                        .accessibilityIdentifier("Password")
                        .padding(.bottom, 12)
                    }
                    .padding(.horizontal, 24)

                    if let error = viewModel.clerkError {
                        ErrorMessageView(message: error)
                            .accessibilityIdentifier("Error")
                    }

                    LoadingButton(
                        title: "Sign In",
                        isLoading: false
                    ) {
                        Task { await viewModel.signInClerk(email: email, password: password) }
                    }
                    .accessibilityIdentifier("Sign In")
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .onAppear {
                viewModel.clerkError = nil
            }
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthViewModel())
}
