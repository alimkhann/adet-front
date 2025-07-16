import SwiftUI

struct EmailSignUpFormView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    let onboardingAnswers: OnboardingAnswers
    @State private var email    = ""
    @State private var username = ""
    @State private var password = ""
    @State private var repeatPassword = ""
    @State private var agreedToTerms = false
    @State private var passwordMismatch = false
    @FocusState private var emailFieldFocused: Bool
    @FocusState private var passwordFieldFocused: Bool
    @State private var showVerificationField = false
    @State private var verificationCode = ""
    @State private var isVerifying = false

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
        VStack {
            LargeRoundedTextView(label: "Create Account")
                .padding(.top, 40)
                .padding(.bottom, 32)
            StyledTextField(
                placeholder: "Email",
                text: $email)
                .accessibilityIdentifier("Email")
                .padding(.bottom, 12)
                .focused($emailFieldFocused)
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
                .padding(.bottom, 4)
                .focused($passwordFieldFocused)
            PasswordStrengthView(strength: passwordStrength)
                .padding(.bottom, 8)
            StyledTextField(
                placeholder: "Repeat Password",
                text: $repeatPassword,
                isSecure: true
            )
                .padding(.bottom, 12)
                .accessibilityIdentifier("RepeatPassword")
                .padding(.bottom, 4)
            if !repeatPassword.isEmpty && !passwordsMatch {
                Text("Passwords do not match.")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.bottom, 8)
            }

            // Verification code field (between repeat password and agreement)
            if showVerificationField {
                StyledTextField(
                    placeholder: "Enter Verification Code",
                    text: $verificationCode
                )
                .accessibilityIdentifier("Verification Code")
                .padding(.bottom, 8)
            }

            HStack(alignment: .center, spacing: 8) {
                Button(action: { agreedToTerms.toggle() }) {
                    Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                        .foregroundColor(agreedToTerms ? .accentColor : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                HStack(spacing: 0) {
                    Text("I agree to the ")
                    Text("Privacy Policy")
                        .foregroundColor(.accentColor)
                        .underline()
                        .onTapGesture {
                            if let url = URL(string: "https://tryadet.com/privacy-policy") {
                                UIApplication.shared.open(url)
                            }
                        }
                    Text(" and ")
                    Text("Terms of Service")
                        .foregroundColor(.accentColor)
                        .underline()
                        .onTapGesture {
                            if let url = URL(string: "https://tryadet.com/terms-of-service") {
                                UIApplication.shared.open(url)
                            }
                        }
                }
                .font(.footnote)
            }
            .font(.footnote)
            .padding(.bottom, 8)

            // Button logic
            if showVerificationField {
                LoadingButton(
                    title: "Verify",
                    isLoading: isVerifying
                ) {
                    Task { await viewModel.verifyClerk(verificationCode) }
                }
                .accessibilityIdentifier("Verify")
                .disabled(isVerifying || verificationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                LoadingButton(
                    title: "Get Started",
                    isLoading: false
                ) {
                    if passwordsMatch {
                        passwordMismatch = false
                        Task {
                            await viewModel.signUpClerk(
                                email: email,
                                password: password,
                                username: username,
                                answers: onboardingAnswers
                            )
                            
                            showVerificationField = true
                        }
                    } else {
                        passwordMismatch = true
                    }
                }
                .accessibilityIdentifier("Sign Up")
                .disabled(!canSignUp)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .tint(.primary)
        .onAppear { viewModel.clearErrors() }
    }
}

// Password strength logic
struct PasswordStrength {
    let value: Int
    let description: String
    let color: Color

    init(_ password: String) {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{}|;:'\",.<>?/`~")) != nil { score += 1 }
        self.value = score
        switch score {
        case 0...1:
            self.description = "Very Weak"
            self.color = .red
        case 2:
            self.description = "Weak"
            self.color = .orange
        case 3:
            self.description = "Medium"
            self.color = .yellow
        case 4:
            self.description = "Strong"
            self.color = .green
        case 5:
            self.description = "Very Strong"
            self.color = .blue
        default:
            self.description = ""
            self.color = .clear
        }
    }
}

struct PasswordStrengthView: View {
    let strength: PasswordStrength
    var body: some View {
        HStack(spacing: 8) {
            Text("Password strength: ")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(strength.description)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(strength.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
