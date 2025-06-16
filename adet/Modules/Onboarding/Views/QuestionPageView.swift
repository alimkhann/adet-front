import SwiftUI

struct QuestionPageView: View {
    let step: OnboardingStep
    @Binding var answer: String
    @State private var isCustomEntry = false
    @Binding var extraDescription: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            Text(step.title)
                .foregroundColor(.primary)
                .font(.title2)
                .fontWeight(.semibold)

            Text(step.subtitle)
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.7))
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
                                            ? Color.primary
                                            : (colorScheme == .dark ? Color.zinc900 : Color.zinc100)
                                        )
                                )
                                .foregroundColor(
                                    answer == option
                                    ? (colorScheme == .dark ? .black : .white)
                                    : (colorScheme == .dark ? .white : .black)
                                )
                        }
                    }

                    if isCustomEntry {
                        StyledTextField(
                            placeholder: "Type your own…",
                            text: $answer
                        )
                        .background(colorScheme == .dark ? Color.zinc900 : Color.zinc100)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .cornerRadius(10)
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
                                        .fill(colorScheme == .dark ? Color.zinc900 : Color.zinc100)
                                )
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }
                    }
                }
                .padding(.horizontal, 24)
            } else {
                StyledTextField(
                    placeholder: "Enter your answer…",
                    text: $answer
                )
                .background(colorScheme == .dark ? Color.zinc900 : Color.zinc100)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .cornerRadius(10)
                .padding(.horizontal, 24)
            }

            if step.id == onboardingSteps.first!.id {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $extraDescription)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .background(colorScheme == .dark ? Color.zinc900 : Color.zinc100)
                        .cornerRadius(10)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .disableAutocorrection(true)

                    if extraDescription.isEmpty {
                        Text("More details (optional)…")
                            .foregroundColor(.primary.opacity(0.3))
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
