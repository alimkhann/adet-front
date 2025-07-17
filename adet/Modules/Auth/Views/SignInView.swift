import SwiftUI
import Clerk

struct SignInView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @AppStorage("appLanguage") private var language: String = "en"
    @Environment(\.colorScheme) var colorScheme

    @State private var email     = ""
    @State private var password  = ""
    @State private var showEmailFields = false
    @State private var showEmailForm = false // New state for navigation

    var body: some View {
        NavigationStack {
            VStack {
                LargeRoundedTextView(label: "Sign Into Account")
                    .padding(.top, 40)
                    .padding(.bottom, 32)

                // Social Auth Buttons
                VStack(spacing: 12) {
                    Spacer()
                        .frame(height: 160)

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
                    EmailSignInFormView().environmentObject(viewModel)
                }

                Spacer()
            }
        }
        .tint(.primary)
        .onAppear {
            viewModel.clearErrors()
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthViewModel())
}
