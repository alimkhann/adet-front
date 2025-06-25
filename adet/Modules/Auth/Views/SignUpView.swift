import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var viewModel: AuthViewModel

    let onboardingAnswers: OnboardingAnswers

    @State private var email    = ""
    @State private var username = ""
    @State private var password = ""
    @State private var code     = ""

    var body: some View {
        NavigationStack {
            ZStack {
                GradientBackgroundView()

                VStack {
                    LargeRoundedTextView(label: "Create Account")
                        .padding(.top, 40)
                        .padding(.bottom, 32)

                    Group {
                        StyledTextField(
                            placeholder: "Email",
                            text: $email)
                        .accessibilityIdentifier("Email")
                        .padding(.bottom, 12)

                        StyledTextField(
                            placeholder: "Username",
                            text: $username
                        )
                        .accessibilityIdentifier("Username")
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

                    if viewModel.isClerkVerifying {
                        StyledTextField(
                            placeholder: "Verification Code",
                            text: $code
                        )
                        .accessibilityIdentifier("VerificationCode")
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                        LoadingButton(
                            title: "Verify",
                            isLoading: false
                        ) {
                            Task { await viewModel.verifyClerk(code) }
                        }
                        .accessibilityIdentifier("Verify")
                        .padding(.horizontal, 24)
                    } else {
                        LoadingButton(
                            title: "Get Started",
                            isLoading: false
                        ) {
                            Task { await viewModel.signUpClerk(
                                email: email,
                                password: password,
                                username: username,
                                answers: onboardingAnswers
                            ) }
                        }
                        .accessibilityIdentifier("Sign Up")
                        .padding(.horizontal, 24)
                    }

                    NavigationLink("Already have an account? Sign In", destination: SignInView())
                        .foregroundColor(.primary.opacity(0.7))
                        .font(.footnote)
                        .padding(.top, 12)

                    Spacer()
                }
            }
            .onAppear {
                viewModel.clearErrors()
            }
        }
    }
}
