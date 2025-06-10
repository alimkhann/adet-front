import SwiftUI

struct WelcomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.black), Color(.darkGray)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    Text("ädet")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundLinearGradient(
                            colors: [Color.white, Color(.lightGray)],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                    Text("Build habits that last.")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    Spacer()

                    VStack(spacing: 16) {
                        NavigationLink {
                            OnboardingView()
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
}

#Preview {
    WelcomeView()
}
