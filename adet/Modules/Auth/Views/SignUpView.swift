import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var viewModel: AuthViewModel

    @State private var username  = ""
    @State private var email     = ""
    @State private var password  = ""

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackgroundView()

                VStack {
                    LargeRoundedTextView(label: "Create Account")                        .padding(.top, 40)
                        .padding(.bottom, 32)

                    Group {
                        StyledTextField(
                            placeholder: "Username",
                            text: $username
                        )
                        .accessibilityIdentifier("Username")
                        .padding(.bottom, 12)

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

                    ErrorMessageView(message: viewModel.authError)
                        .accessibilityIdentifier("Error")

                    LoadingButton(
                        title: "Sign Up",
                        isLoading: viewModel.isLoading
                    ) {
                        viewModel.signUp(email: email, username: username, password: password)
                    }
                    .accessibilityIdentifier("Sign Up")
                    .padding(.horizontal, 24)

                    NavigationLink("Already have an account? Sign In", destination: SignInView())
                        .foregroundColor(.primary.opacity(0.7))
                        .font(.footnote)
                        .padding(.top, 12)

                    Spacer()
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { viewModel.user != nil },
                set: { _ in }
            ), destination: {
                TabBarView()
            })
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environmentObject(AuthViewModel())
    }
}
