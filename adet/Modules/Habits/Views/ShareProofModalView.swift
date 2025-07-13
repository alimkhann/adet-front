import SwiftUI
import Kingfisher

struct ShareProofModalView: View {
    let task: HabitTaskDetails
    let proof: HabitProofState
    let onShare: (String, String, ProofInputType, String?) -> Void
    let closeFriendsCount: Int
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
                        .background(selectedVisibility == "Close Friends" ? Color.black.opacity(closeFriendsCount > 0 ? 1.0 : 0.2) : Color.white)
                        .foregroundColor(selectedVisibility == "Close Friends" ? .white : .black)
                        .cornerRadius(10)
                }
                .disabled(closeFriendsCount == 0)
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
        case .readyToSubmit(let proofData):
            switch proofData {
            case .image(let data):
                if let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Text("Image proof ready to submit!")
                }
            case .video(let data):
                Text("Video proof attached (\(data.count) bytes)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            case .audio(let data):
                Text("Audio proof attached (\(data.count) bytes)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            case .text(let text):
                Text(text)
                    .font(.body)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
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
