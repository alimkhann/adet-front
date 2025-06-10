import SwiftUI

struct SignInView: View {
    @EnvironmentObject var viewModel: AuthViewModel

    @State private var email     = ""
    @State private var password  = ""

    var body: some View {
        ZStack {
            GradientBackgroundView()

            VStack {
                Text("Sign Into Account")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundLinearGradient(
                        colors: [Color.white, Color(.lightGray)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
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

                ErrorMessageView(message: viewModel.authError)
                    .accessibilityIdentifier("Error")

                LoadingButton(
                    title: "Sign In",
                    isLoading: viewModel.isLoading
                ) {
                    viewModel.signIn(email: email, password: password)
                }
                .accessibilityIdentifier("Sign In")
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthViewModel())
}
