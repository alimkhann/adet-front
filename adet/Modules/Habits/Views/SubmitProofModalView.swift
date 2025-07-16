import SwiftUI
import PhotosUI
import Foundation
import AVFoundation
import UIKit

public enum ProofInputType: String, CaseIterable {
    case photo = "Photo"
    // case video = "Video"
    // case audio = "Audio"
    case text = "Text"
}

struct SubmitProofModalView: View {
    @Binding var proofState: HabitProofState
    let instruction: String
    let validationTime: Date
    let proofType: ProofInputType
    let onSubmit: (ProofInputType, Data?, String?) -> Void
    let image: UIImage?
    @State private var showPhotoPicker = false
    @State private var showVideoPicker = false
    @State private var showAudioPicker = false
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var videoURL: URL? = nil
    @State private var audioURL: URL? = nil
    @State private var textProof: String = ""
    @State private var now: Date = Date()
    private var timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var showCameraSheet = false
    @State private var showVideoCameraSheet = false
    @State private var showAudioRecorder = false
    @State private var isRecordingAudio = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioSession: AVAudioSession? = nil
    @State private var audioFileURL: URL? = nil
    @State private var selectedImage: UIImage? = nil // Add this state for camera capture
    @State private var previewImage: UIImage? = nil

    public init(
        proofState: Binding<HabitProofState>,
        instruction: String,
        validationTime: Date,
        proofType: ProofInputType,
        onSubmit: @escaping (ProofInputType, Data?, String?) -> Void,
        image: UIImage?
    ) {
        self._proofState = proofState
        self.instruction = instruction
        self.validationTime = validationTime
        self.proofType = proofType
        self.onSubmit = onSubmit
        self.image = image
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Submit Proof")
                .font(.title2).bold()
                .padding(.top, 8)

            switch proofState {
            case .notStarted, .readyToSubmit:
                OutlinedBox {
                    Text(instruction)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    ProofWindowTimerView(validationTime: validationTime)
                    Spacer()
                }
                proofInputSection.disabled(false)
                if proofType != .text {
                    proofPreviewSection
                }
                Spacer()
                Button(action: submitProof) {
                    Text("Submit Proof")
                        .frame(minHeight: 44)
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(!isProofReady)

            case .uploading, .validating:
                OutlinedBox {
                    Text(instruction)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    ProofWindowTimerView(validationTime: validationTime)
                    Spacer()
                }
                proofInputSection.disabled(true)
                proofPreviewSection
                Spacer()
                Button(action: {}) {
                    Text(proofState == .uploading ? "Uploading..." : "Validating...")
                        .frame(minHeight: 44)
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(true)
                // Disable drag-to-dismiss and background tap
                .interactiveDismissDisabled(true)

            case .submitted:
                Text("Proof submitted! AI says: Great job!").font(.title2).foregroundColor(.green)
            case .error(let message):
                Text("Error: \(message)").foregroundColor(.red)
            }
        }
        .padding()
        // Make modal undismissable during uploading/validating
        .interactiveDismissDisabled(proofState == .uploading || proofState == .validating)
        .onChange(of: proofState) { oldValue, newValue in
            if case .notStarted = newValue {
                // previewImage = nil // REMOVE: previewImage = nil
            }
        }
    }

    @ViewBuilder
    private var proofInputSection: some View {
        switch proofType {
        case .photo:
            VStack {
                HStack(spacing: 12) {
                    Button {
                        selectedItem = nil
                        showPhotoPicker = true
                    } label: {
                        Text("Upload Photo")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .photosPicker(
                        isPresented: $showPhotoPicker,
                        selection: $selectedItem,
                        matching: .images,
                        preferredItemEncoding: .automatic
                    )
                    .onChange(of: selectedItem) { oldValue, newValue in
                        guard let item = newValue else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                previewImage = uiImage
                                proofState = .readyToSubmit(.image(data))
                            }
                        }
                    }

                    Button { showCameraSheet = true } label: {
                        Text("Take Photo")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .sheet(isPresented: $showCameraSheet) {
                ImagePicker(sourceType: .camera, selectedImage: $previewImage)
            }
            .onChange(of: previewImage) { oldValue, newValue in
                if let img = newValue, let data = img.jpegData(compressionQuality: 0.9) {
                    proofState = .readyToSubmit(.image(data))
                }
            }

        // case .video:
        //     HStack(spacing: 12) {
        //         Button(action: { showVideoPicker = true }) {
        //             Text(videoURL == nil ? "Upload Video" : "Change Video")
        //                 .frame(maxWidth: .infinity, minHeight: 44)
        //         }
        //         .buttonStyle(SecondaryButtonStyle())
        //         .fileImporter(isPresented: $showVideoPicker, allowedContentTypes: [.movie, .video]) { result in
        //             switch result {
        //             case .success(let url):
        //                 videoURL = url
        //                 if let data = try? Data(contentsOf: url) {
        //                     proofState = .readyToSubmit(.video(data))
        //                 }
        //             default: break
        //             }
        //         }
        //         Button(action: { showVideoCameraSheet = true }) {
        //             Text("Record Video")
        //                 .frame(maxWidth: .infinity, minHeight: 44)
        //         }
        //         .buttonStyle(PrimaryButtonStyle())
        //     }
        //     .sheet(isPresented: $showVideoCameraSheet) {
        //         VideoPicker(sourceType: .camera) { url in
        //             if let url = url, let data = try? Data(contentsOf: url) {
        //                 videoURL = url
        //                 proofState = .readyToSubmit(.video(data))
        //             }
        //             showVideoCameraSheet = false
        //         }
        //     }

        // case .audio:
        //     HStack(spacing: 12) {
        //         Button(action: { showAudioPicker = true }) {
        //             Text(audioURL == nil ? "Upload Audio" : "Change Audio")
        //                 .frame(maxWidth: .infinity, minHeight: 44)
        //         }
        //         .buttonStyle(SecondaryButtonStyle())
        //         .fileImporter(isPresented: $showAudioPicker, allowedContentTypes: [.audio]) { result in
        //             switch result {
        //             case .success(let url):
        //                 audioURL = url
        //                 if let data = try? Data(contentsOf: url) {
        //                     proofState = .readyToSubmit(.audio(data))
        //                 }
        //             default: break
        //             }
        //         }
        //         Button(action: {
        //             if isRecordingAudio {
        //                 stopAudioRecording()
        //             } else {
        //                 startAudioRecording()
        //             }
        //         }) {
        //             Text(isRecordingAudio ? "Stop Recording" : "Record Audio")
        //                 .frame(maxWidth: .infinity, minHeight: 44)
        //         }
        //         .buttonStyle(PrimaryButtonStyle())
        //     }

        case .text:
            VStack(alignment: .leading) {
                Text("Enter your proof:")
                TextEditor(text: $textProof)
                    .frame(maxHeight: .infinity)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
                    .onChange(of: textProof) { oldValue, newValue in
                        proofState = newValue.isEmpty ? .notStarted : .readyToSubmit(.text(newValue))
                    }
            }
        }
    }

    // MARK: - Helpers (moved out of ViewBuilder)
    /// Whether we have valid proof data ready to submit
    private var isProofReady: Bool {
        switch proofType {
        case .photo:
            if case let .readyToSubmit(proofData) = proofState, case .image = proofData { return true }
            return false
        case .text:
            if case let .readyToSubmit(proofData) = proofState, case .text = proofData { return true }
            return false
        }
    }

    /// Called when the "Submit Proof" button is tapped
    private func submitProof() {
        switch proofType {
        case .photo:
            guard let data = previewImage?.jpegData(compressionQuality: 0.9) else {
                ToastManager.shared.showError("No photo selected."); return
            }
            onSubmit(.photo, data, nil)
            ToastManager.shared.showSuccess("Photo proof submitted!")
        case .text:
            guard !textProof.isEmpty else {
                ToastManager.shared.showError("No text entered."); return
            }
            onSubmit(.text, nil, textProof)
            ToastManager.shared.showSuccess("Text proof submitted!")
        }
    }

    @ViewBuilder
    private var proofPreviewSection: some View {
        switch proofType {
        case .photo:
            if let img = previewImage ?? image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                        .foregroundColor(.gray.opacity(0.5))
                        .frame(maxHeight: .infinity)
                    VStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("Add a photo as proof")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
        case .text:
            EmptyView()
        }
    }
}
