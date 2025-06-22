import SwiftUI

struct QuestionPageView: View {
    let step: OnboardingStep
    @Binding var answers: OnboardingAnswers
    @State private var isCustomEntry = false
    @State private var isTimePicker = false
    @State private var isWeekdayPicker = false
    @State private var selectedTime = Date()
    @Environment(\.colorScheme) private var colorScheme

    private var answerBinding: Binding<String> {
        Binding<String>(
            get: {
                switch step.id {
                case onboardingSteps[0].id: return self.answers.habitName
                case onboardingSteps[1].id: return self.answers.frequency
                case onboardingSteps[2].id: return self.answers.validationTime
                case onboardingSteps[3].id: return self.answers.difficulty
                case onboardingSteps[4].id: return self.answers.proofStyle
                default: return ""
                }
            },
            set: { newValue in
                switch step.id {
                case onboardingSteps[0].id: self.answers.habitName = newValue
                case onboardingSteps[1].id: self.answers.frequency = newValue
                case onboardingSteps[2].id: self.answers.validationTime = newValue
                case onboardingSteps[3].id: self.answers.difficulty = newValue
                case onboardingSteps[4].id: self.answers.proofStyle = newValue
                default: break
                }
            }
        )
    }

    private var extraDescriptionBinding: Binding<String> {
        Binding<String>(
            get: { self.answers.habitDescription ?? "" },
            set: { self.answers.habitDescription = $0 }
        )
    }

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
                            answerBinding.wrappedValue = option
                            isCustomEntry = false
                            isTimePicker = false
                            isWeekdayPicker = false
                        } label: {
                            Text(option)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            answerBinding.wrappedValue == option
                                            ? Color.primary
                                            : (colorScheme == .dark ? Color.zinc900 : Color.zinc100)
                                        )
                                )
                                .foregroundColor(
                                    answerBinding.wrappedValue == option
                                    ? (colorScheme == .dark ? .black : .white)
                                    : (colorScheme == .dark ? .white : .black)
                                )
                        }
                    }

                    if isTimePicker && step.title.contains("validation/proof time") {
                        TimePickerView(selectedTime: $selectedTime, answer: answerBinding)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(colorScheme == .dark ? Color.zinc900 : Color.zinc100)
                            )
                    } else if isWeekdayPicker && step.title.contains("frequency") {
                        WeekdayPickerView(answer: answerBinding)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(colorScheme == .dark ? Color.zinc900 : Color.zinc100)
                            )
                    } else if isCustomEntry {
                        StyledTextField(
                            placeholder: "Type your own…",
                            text: answerBinding
                        )
                        .background(colorScheme == .dark ? Color.zinc900 : Color.zinc100)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .cornerRadius(10)
                    } else if options.contains("Other") {
                        Button {
                            answerBinding.wrappedValue = ""
                            isCustomEntry = false
                            isTimePicker = false
                            isWeekdayPicker = false

                            if step.title.contains("validation/proof time") {
                                isTimePicker = true
                                selectedTime = Date()
                                let formatter = DateFormatter()
                                formatter.timeStyle = .short
                                answerBinding.wrappedValue = formatter.string(from: selectedTime)
                            } else if step.title.contains("frequency") {
                                isWeekdayPicker = true
                            } else {
                                isCustomEntry = true
                            }
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
                    text: answerBinding
                )
                .background(colorScheme == .dark ? Color.zinc900 : Color.zinc100)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .cornerRadius(10)
                .padding(.horizontal, 24)
            }

            if step.id == onboardingSteps.first!.id {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: extraDescriptionBinding)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .background(colorScheme == .dark ? Color.zinc900 : Color.zinc100)
                        .cornerRadius(10)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .disableAutocorrection(true)

                    if extraDescriptionBinding.wrappedValue.isEmpty {
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

struct TimePickerView: View {
    @Binding var selectedTime: Date
    @Binding var answer: String

    var body: some View {
        DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 120)
            .clipped()
            .onChange(of: selectedTime) { newTime, _ in
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                answer = formatter.string(from: newTime)
            }
    }
}

struct WeekdayPickerView: View {
    @Binding var answer: String
    @State private var selectedDays: [Bool] = Array(repeating: false, count: 7)
    @Environment(\.colorScheme) private var colorScheme

    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        HStack {
            ForEach(0..<7, id: \.self) { index in
                Button(action: {
                    selectedDays[index].toggle()
                    updateAnswer()
                }) {
                    Text(weekdays[index])
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 36, height: 36)
                        .foregroundColor(selectedDays[index] ? (colorScheme == .dark ? .black : .white) : .primary)
                        .background(
                            Circle()
                                .fill(selectedDays[index] ? Color.primary : Color.clear)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .onAppear(perform: parseAnswer)
    }

    private func updateAnswer() {
        let fullWeekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let selected = selectedDays.indices.filter { selectedDays[$0] }.map { fullWeekdays[$0] }

        if selected.isEmpty {
            answer = ""
        } else if selected.count == 7 {
            answer = "Every day"
        } else if selected == ["Sat", "Sun"] {
            answer = "Weekends"
        } else if selected == ["Mon", "Tue", "Wed", "Thu", "Fri"] {
            answer = "Weekdays"
        } else {
            answer = selected.joined(separator: ", ")
        }
    }

    private func parseAnswer() {
        let fullWeekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let components = answer.components(separatedBy: ", ")
        for (index, day) in fullWeekdays.enumerated() {
            if components.contains(day) {
                selectedDays[index] = true
            }
        }
    }
}
