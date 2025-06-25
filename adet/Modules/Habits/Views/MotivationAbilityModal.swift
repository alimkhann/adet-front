import SwiftUI
import Combine

struct MotivationAbilityModal: View {
    @Binding var isPresented: Bool
    @Binding var isLoading: Bool
    let habitName: String
    let todayMotivation: MotivationEntryResponse?
    let onSubmitMotivation: (String) async -> Bool
    let onSubmitAbility: (String) async -> Bool

    @State private var step: Int = 0 // 0 = Motivation, 1 = Ability
    @State private var motivation: String? = nil
    @State private var ability: String? = nil
    @Namespace private var animation

    let motivationOptions = ["Low", "Medium", "High"]
    let abilityChoices = ["Hard", "Medium", "Easy"]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                // Step indicator
                VStack(spacing: 8) {
                    Text("Step \(step + 1) of 2")
                        .font(.subheadline)
                        .foregroundColor(.primary.opacity(0.7))
                    HStack(spacing: 8) {
                        ForEach(0..<2, id: \ .self) { idx in
                            Circle()
                                .fill(step == idx ? Color.primary : Color.primary.opacity(0.2))
                                .frame(width: 8, height: 8)
                                .scaleEffect(step == idx ? 1.2 : 1)
                                .animation(.spring(response: 0.3), value: step)
                        }
                    }
                }
                .padding(.top, 20)

                // Habit name (moved above question)
                Text(habitName)
                    .font(.headline)
                    .foregroundColor(.primary.opacity(0.7))
                    .padding(.bottom, 0)

                // Question
                Text(step == 0 ? "How motivated are you today?" : "How able are you to do this habit today?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .matchedGeometryEffect(id: "question", in: animation)

                // Options (Onboarding style)
                VStack(spacing: 16) {
                    ForEach((step == 0 ? motivationOptions : abilityChoices), id: \ .self) { option in
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if step == 0 { motivation = option } else { ability = option }
                        } label: {
                            Text(option)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedOption(option) ? Color.primary : Color(.systemGray6))
                                )
                                .foregroundColor(selectedOption(option) ? Color(.systemBackground) : .primary)
                                .animation(.easeInOut(duration: 0.18), value: selectedOption(option))
                        }
                        .disabled(isLoading)
                    }
                }
                .padding(.horizontal, 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 0)

            Spacer(minLength: 0)

            // Action buttons
            HStack(spacing: 16) {
                if step == 1 {
                    Button {
                        withAnimation { step = 0 }
                    } label: {
                        Text("Back")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                Button {
                    Task {
                        if step == 0, let chosenMotivation = motivation {
                            isLoading = true
                            let success = await onSubmitMotivation(chosenMotivation)
                            isLoading = false
                            if success {
                                withAnimation { step = 1 }
                            } else {
                                ToastManager.shared.showError("Something went wrong. Try again.")
                            }
                        } else if step == 1, let chosenAbility = ability {
                            isLoading = true
                            let success = await onSubmitAbility(chosenAbility)
                            isLoading = false
                            if success {
                                isPresented = false
                                step = 0
                                motivation = nil
                                ability = nil
                            } else {
                                ToastManager.shared.showError("Something went wrong. Try again.")
                            }
                        }
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    } else {
                        Text(step == 0 ? "Next" : "Finish")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canProceed || isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .presentationDetents([.fraction(0.65)])
        .interactiveDismissDisabled()
        .background(Color(.systemBackground))
        .onAppear {
            // Pre-select motivation if it exists
            if let entry = todayMotivation {
                motivation = entry.level.capitalized
            }
        }
        .onDisappear {
            // Reset state when modal is dismissed
            step = 0
            motivation = nil
            ability = nil
            isLoading = false
        }
    }

    private func selectedOption(_ option: String) -> Bool {
        if step == 0 { return motivation == option }
        else { return ability == option }
    }
    private var canProceed: Bool {
        if step == 0 { return motivation != nil && !isLoading }
        else { return ability != nil && !isLoading }
    }
}
