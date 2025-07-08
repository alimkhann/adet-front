import SwiftUI
import Kingfisher

struct ShareProofModalView: View {
    let task: HabitTaskDetails
    let proof: HabitProofState
    let onShare: (String, String, ProofInputType, String?) -> Void
    @State private var description: String = ""
    @State private var selectedVisibility: String = "Friends"
    @State private var proofInputType: ProofInputType = .photo
    @State private var textProof: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            Text("Share")
                .font(.title2).bold()
                .padding(.top, 8)

            OutlinedBox {
                Text(task.description)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            proofPreview

            TextField("Share your thoughts...", text: $description)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Who can see this?")
                HStack(spacing: 12) {
                    Button(action: { selectedVisibility = "Friends" }) {
                        Text("Friends")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(selectedVisibility == "Friends" ? Color.black : Color.white)
                            .foregroundColor(selectedVisibility == "Friends" ? .white : .black)
                            .cornerRadius(10)
                    }
                    Button(action: { selectedVisibility = "Close Friends" }) {
                        Text("Close Friends")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(selectedVisibility == "Close Friends" ? Color.black : Color.white)
                            .foregroundColor(selectedVisibility == "Close Friends" ? .white : .black)
                            .cornerRadius(10)
                    }
                }
            }

            Button(action: {
                onShare(selectedVisibility, description, proofInputType, textProof)
            }) {
                Text("Share")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 8)
        }
        .padding()
    }

    @ViewBuilder
    private var proofPreview: some View {
        switch proof {
        case .readyToSubmit(let imageData):
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if let data = imageData, let urlString = String(data: data, encoding: .utf8), let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true {
                KFImage(url)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Text("Proof ready to submit!")
            }
        case .submitted:
            Text("Proof submitted!")
        case .error(let message):
            OutlinedBox {
                Text(message).foregroundColor(.red)
            }
        default:
            Text("No proof preview available.")
        }
    }
}

#Preview {
    ShareProofModalView(
        task: HabitTaskDetails(
            description: "Take a 10-minute walk around your neighborhood",
            easierAlternative: "Walk to your mailbox and back",
            harderAlternative: "Take a 20-minute brisk walk with some hills",
            motivation: "High",
            ability: "Easy",
            timeLeft: TimeInterval(3600) // 1 hour left
        ),
        proof: .readyToSubmit(image: nil),
        onShare: { visibility, description, proofType, textProof in
            print("Sharing with visibility: \(visibility), description: \(description)")
        }
    )
}
