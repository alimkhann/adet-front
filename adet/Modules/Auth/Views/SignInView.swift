import SwiftUI

struct SignInView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @AppStorage("appLanguage") private var language: String = "en"

    @State private var email     = ""
    @State private var password  = ""

    var body: some View {
        NavigationStack {
            VStack {
                LargeRoundedTextView(label: "Sign Into Account")
                    .padding(.top, 40)
                    .padding(.bottom, 32)

                Group {
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
                }
                .padding(.horizontal, 24)

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
            viewModel.clearErrors()
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthViewModel())
}
