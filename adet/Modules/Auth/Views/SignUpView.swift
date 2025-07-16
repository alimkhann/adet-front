import SwiftUI
import Clerk

struct SignUpView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme

    let onboardingAnswers: OnboardingAnswers

    @State private var email    = ""
    @State private var username = ""
    @State private var password = ""
    @State private var repeatPassword = ""
    @State private var code     = ""
    @State private var passwordMismatch = false
    @State private var agreedToTerms = false
    @FocusState private var emailFieldFocused: Bool
    @FocusState private var passwordFieldFocused: Bool
    @State private var showEmailFields = false
    @State private var showEmailForm = false // New state for navigation

    var passwordsMatch: Bool {
        !password.isEmpty && password == repeatPassword
    }

    var passwordStrength: PasswordStrength {
        PasswordStrength(password)
    }

    var canSignUp: Bool {
        passwordsMatch && agreedToTerms && !email.isEmpty && !username.isEmpty && !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack {
                LargeRoundedTextView(label: "Create Account")
                    .padding(.top, 40)
                    .padding(.bottom, 32)

                Spacer()

                // Social Auth Buttons
                VStack(spacing: 12) {
                    SignInWithAppleView()
                        .frame(height: 48)
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3), lineWidth: 1)
                                .padding(.horizontal, 24)
                        )

                    Button(action: {
                        showEmailForm = true
                    }) {
                        Text("Continue with Email")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)
                .navigationDestination(isPresented: $showEmailForm) {
                    EmailSignUpFormView(onboardingAnswers: onboardingAnswers).environmentObject(viewModel)
                }

                NavigationLink("Already have an account? Sign In", destination: SignInView())
                    .foregroundColor(.primary.opacity(0.7))
                    .font(.footnote)
                    .padding(.top, 12)

                Spacer()
            }
        }
        .tint(.primary)
        .onAppear {
            viewModel.clearErrors()
        }
    }
}
