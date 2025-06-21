import SwiftUI

struct SignInView: View {
    @EnvironmentObject var viewModel: AuthViewModel

    @State private var email     = ""
    @State private var password  = ""

    var body: some View {
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
            // Clear any existing errors when view appears
            viewModel.clerkError = nil
        }
        .navigationDestination(isPresented: Binding(
            get: { viewModel.user != nil },
            set: { _ in }
        ), destination: {
            TabBarView()
        })
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthViewModel())
}
