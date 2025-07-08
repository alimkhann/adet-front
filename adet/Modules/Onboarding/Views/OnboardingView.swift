import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var answers = OnboardingAnswers()
    @State private var isFinished = false

    var body: some View {
        NavigationStack {
            VStack {
                VStack(spacing: 8) {
                    Text("Step \(currentStep + 1) of \(onboardingSteps.count)")
                        .font(.subheadline)
                        .foregroundColor(.primary.opacity(0.7))

                    HStack(spacing: 8) {
                        ForEach(0..<onboardingSteps.count, id: \.self) { index in
                            Circle()
                                .fill(currentStep == index ? Color.white : Color.primary.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(currentStep == index ? 1.2 : 1)
                                .animation(.spring(response: 0.3), value: currentStep)
                        }
                    }
                }
                .padding(.top, 20)

                TabView(selection: $currentStep) {
                    ForEach(onboardingSteps.indices, id: \.self) { index in
                        QuestionPageView(
                            step: onboardingSteps[index],
                            answers: $answers
                        )
                        .tag(index)
                        .padding()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)

                Spacer()

                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button {
                            currentStep -= 1
                        } label: {
                            Text("Back")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }

                    Button {
                        if currentStep < onboardingSteps.count - 1 {
                            currentStep += 1
                        } else {
                            isFinished = true
                        }
                    } label: {
                        Text(currentStep < onboardingSteps.count - 1 ? "Next" : "Create Account")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 24)
            }
            .foregroundStyle(.white)
            .navigationDestination(isPresented: $isFinished) {
                SignUpView(onboardingAnswers: answers)
            }
        }
        .tint(.primary)
    }
}

#Preview {
    OnboardingView()
}
