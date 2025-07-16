import SwiftUI

struct WelcomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()
                
                LargeRoundedTextView(label: "ädet")
                
                Text("Build habits that last.")
                    .font(.headline)
                    .foregroundColor(.primary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                Spacer()
                
                VStack(spacing: 16) {
                    NavigationLink {
                        RegistrationOnboardingView()
                    } label: {
                        Text("Get Started")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("Get Started")
                    
                    NavigationLink {
                        SignInView()
                    } label: {
                        Text("I already have an account")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("I already have an account")
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical)
        }
    }
}

#Preview {
    WelcomeView()
}
