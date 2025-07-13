import SwiftUI

struct ProofSectionView: View {
    @Binding var proof: HabitProofState
    let onSubmitProof: (ProofInputType, Data?, String?) -> Void
    let isGenerating: Bool
    let validationTime: Date?
    let onRetry: () -> Void
    @EnvironmentObject var viewModel: HabitViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isGenerating {
                OutlinedBox {
                    TypingText(text: "Generating Proof", animatedDots: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else {
                switch proof {
                case .uploading, .validating:
                    OutlinedBox {
                        TypingText(text: "Generating Proof", animatedDots: true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                case .notStarted:
                    OutlinedBox {
                        TypingText(text: viewModel.todayTask?.proofRequirements ?? "")
                            .id(viewModel.typingTextProofKey)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                    Button(action: { onSubmitProof(.photo, nil, nil) }) {
                        Text("Submit Proof")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
                case .error(let message):
                    OutlinedBox {
                        Text("Error: \(message)").foregroundColor(Color.red)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                    Button(action: {
                        onRetry()
                    }) {
                        Text("Try Again")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                default:
                    OutlinedBox {
                        Text("Error: Unsupported proof case.").foregroundColor(Color.red)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                    Button(action: {
                        onRetry()
                    }) {
                        Text("Try Again")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
