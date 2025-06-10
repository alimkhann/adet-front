import SwiftUI

struct QuestionPageView: View {
    let step: OnboardingStep
    @Binding var answer: String
    @State private var isCustomEntry = false
    @Binding var extraDescription: String

    private let selectedGradient = LinearGradient(
        colors: [Color.blue, Color.purple],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 24) {
            Text(step.title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(step.subtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let options = step.options, !options.isEmpty {
                VStack(spacing: 16) {
                    ForEach(options.filter { $0 != "Other" }, id: \.self) { option in
                        Button {
                            answer = option
                            isCustomEntry = false
                        } label: {
                            Text(option)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            answer == option
                                            ? AnyShapeStyle(selectedGradient)
                                            : AnyShapeStyle(.zinc900)
                                        )
                                )
                                .foregroundColor(.white)
                        }
                    }

                    if isCustomEntry {
                        StyledTextField(
                            placeholder: "Type your own…",
                            text: $answer
                        )
                    } else if options.contains("Other") {
                        Button {
                            answer = ""
                            isCustomEntry = true
                        } label: {
                            Text("Other")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            AnyShapeStyle(.zinc900)
                                        )
                                )
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 24)
            } else {
                StyledTextField(
                    placeholder: "Enter your answer…",
                    text: $answer
                )
                .padding(.horizontal, 24)
            }

            if step.id == onboardingSteps.first!.id {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $extraDescription)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .background(.zinc900)
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .disableAutocorrection(true)

                    if extraDescription.isEmpty {
                        Text("More details (optional)…")
                            .foregroundColor(.white.opacity(0.3))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .padding(.top, 12)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 100)
                .padding(.horizontal, 24)
            }
        }
    }
}
