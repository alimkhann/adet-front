import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(title: "Welcome to ädet!", description: "Build habits that last with AI-powered daily tasks and streaks.", imageName: "onboarding1_placeholder"),
        OnboardingPage(title: "Create Your First Habit", description: "Set up your first habit and let AI generate daily challenges tailored to you.", imageName: "onboarding2_placeholder"),
        OnboardingPage(title: "Track Progress & Stay Motivated", description: "Earn streaks, get encouragement, and share your wins with friends.", imageName: "onboarding3_placeholder")
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        VStack(spacing: 32) {
                            Spacer()
                            Image(pages[index].imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 220)
                                .padding(.top, 40)
                                .padding(.bottom, 16)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(16)
                                .overlay(
                                    Text("Screenshot Placeholder")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(4), alignment: .bottom
                                )
                            Text(pages[index].title)
                                .font(.title)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            Text(pages[index].description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Spacer()
                            if index == pages.count - 1 {
                                Button(action: onFinish) {
                                    Text("Get Started")
                                        .frame(maxWidth: .infinity, minHeight: 48)
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .padding(.horizontal, 32)
                                .padding(.bottom, 32)
                            } else {
                                Button(action: {
                                    withAnimation { currentPage += 1 }
                                }) {
                                    Text("Next")
                                        .frame(maxWidth: .infinity, minHeight: 48)
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .padding(.horizontal, 32)
                                .padding(.bottom, 32)
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                Button("Skip") {
                    onFinish()
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
                .padding(.top, 16)
                .padding(.trailing, 20)
            }
            .background(Color(.systemBackground))
            .ignoresSafeArea()
        }
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
}

#Preview {
    OnboardingView(onFinish: {})
}