import SwiftUI
import PhotosUI
import AVFoundation

struct ProofSubmissionModal: View {
    @Binding var isPresented: Bool
    let task: TaskEntry
    let onSubmitProof: (ProofSubmissionData) -> Void

    @State private var proofContent: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedVideo: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var isSubmitting: Bool = false
    @State private var showCamera: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var showVideoPicker: Bool = false
    @State private var showVideoCamera: Bool = false

    // Audio recording states
    @State private var audioRecorder: AVAudioRecorder?
    @State private var isRecording: Bool = false
    @State private var recordingTime: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var audioURL: URL?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingAudio: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Submit Proof")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Requirement:")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(task.proofRequirements)
                        .font(.body)
                        .padding()
                        .background(colorScheme == .dark ? Color.black : Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 1)
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Proof Type Selection - Responsive to preferred style
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose Action:")
                        .font(.headline)

                    switch getPreferredProofType() {
                    case .photo:
                        photoActionsView
                    case .video:
                        videoActionsView
                    case .audio:
                        audioActionsView
                    case .text:
                        textInputView
                    }

                    // Show selected content preview
                    contentPreviewView
                }

                Spacer()

                // Submit Button
                Button(action: submitProof) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                        Text(isSubmitting ? "Validating..." : "Submit Proof")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSubmitting || !canSubmit())
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        stopRecording()
                        isPresented = false
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                selectedImage = image
            }
        }
        .sheet(isPresented: $showVideoCamera) {
            VideoCameraView(selectedVideoURL: $selectedVideoURL)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .photosPicker(isPresented: $showVideoPicker, selection: $selectedVideo, matching: .videos)
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .onChange(of: selectedVideo) { _, newValue in
            Task {
                if let movie = try? await newValue?.loadTransferable(type: Movie.self) {
                    selectedVideoURL = movie.url
                }
            }
        }
        .onAppear {
            setupAudioSession()
        }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - UI Components

    private var photoActionsView: some View {
        HStack(spacing: 12) {
            Button(action: {
                showCamera = true
            }) {
                HStack {
                    Image(systemName: "camera")
                    Text("Take Photo")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button(action: {
                showPhotoPicker = true
            }) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Upload Photo")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var videoActionsView: some View {
        HStack(spacing: 12) {
            Button(action: {
                showVideoCamera = true
            }) {
                HStack {
                    Image(systemName: "video")
                    Text("Record Video")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button(action: {
                showVideoPicker = true
            }) {
                HStack {
                    Image(systemName: "video.badge.plus")
                    Text("Upload Video")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var audioActionsView: some View {
        VStack(spacing: 12) {
            // Recording controls
            HStack(spacing: 16) {
                if isRecording {
                    Button(action: {
                        stopRecording()
                    }) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                                .foregroundColor(.red)
                            Text("Stop Recording")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                } else {
                    Button(action: {
                        startRecording()
                    }) {
                        HStack {
                            Image(systemName: "mic.circle.fill")
                                .foregroundColor(.blue)
                            Text("Start Recording")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                if isRecording {
                    VStack {
                        Text(formatTime(recordingTime))
                            .font(.headline)
                            .foregroundColor(.red)

                        // Recording indicator
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .opacity(isRecording ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(), value: isRecording)
                    }
                }
            }

            // Playback controls
            if audioURL != nil {
                HStack(spacing: 12) {
                    Button(action: {
                        if isPlayingAudio {
                            stopAudioPlayback()
                        } else {
                            playAudio()
                        }
                    }) {
                        HStack {
                            Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                            Text(isPlayingAudio ? "Pause" : "Play Recording")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button(action: {
                        deleteRecording()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    private var textInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Write your proof:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: $proofContent)
                .frame(minHeight: 100)
                .padding(8)
                .background(colorScheme == .dark ? Color.black : Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 1)
                )
        }
    }

    private var contentPreviewView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selectedImage = selectedImage {
                Text("Selected Photo:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(12)
            }

            if let selectedVideoURL = selectedVideoURL {
                Text("Selected Video:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VideoPreview(url: selectedVideoURL)
                    .frame(maxHeight: 200)
                    .cornerRadius(12)
            }

            if audioURL != nil {
                Text("Audio Recording Ready")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Helper Methods

    private func getPreferredProofType() -> TaskProofType {
        return TaskProofType(rawValue: task.proofType ?? "photo") ?? .photo
    }

    private func canSubmit() -> Bool {
        switch getPreferredProofType() {
        case .text:
            return !proofContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .photo:
            return selectedImage != nil
        case .video:
            return selectedVideoURL != nil
        case .audio:
            return audioURL != nil
        }
    }

    private func submitProof() {
        isSubmitting = true

        let proofData = ProofSubmissionData(
            taskId: task.id,
            proofType: getPreferredProofType(),
            proofContent: getProofContentForSubmission(),
            image: selectedImage,
            videoURL: selectedVideoURL,
            audioURL: audioURL
        )

        onSubmitProof(proofData)
    }

    private func getProofContentForSubmission() -> String {
        switch getPreferredProofType() {
        case .text:
            return proofContent
        case .photo:
            return "Photo submitted"
        case .video:
            return "Video submitted"
        case .audio:
            return "Audio recording submitted"
        }
    }

    // MARK: - Audio Recording Methods

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    private func startRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")

        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()

            isRecording = true
            recordingTime = 0
            audioURL = audioFilename

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                recordingTime += 0.1
            }
        } catch {
            print("Could not start recording: \(error)")
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        isRecording = false
    }

    private func playAudio() {
        guard let audioURL = audioURL else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.play()
            isPlayingAudio = true

            // Stop playing indicator when audio finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + (audioPlayer?.duration ?? 0)) {
                isPlayingAudio = false
            }
        } catch {
            print("Could not play audio: \(error)")
        }
    }

    private func stopAudioPlayback() {
        audioPlayer?.stop()
        isPlayingAudio = false
    }

    private func deleteRecording() {
        if let audioURL = audioURL {
            try? FileManager.default.removeItem(at: audioURL)
        }
        audioURL = nil
        stopAudioPlayback()
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Types

struct ProofSubmissionData {
    let taskId: Int
    let proofType: TaskProofType
    let proofContent: String
    let image: UIImage?
    let videoURL: URL?
    let audioURL: URL?
}

// MARK: - Video Camera View

struct VideoCameraView: UIViewControllerRepresentable {
    @Binding var selectedVideoURL: URL?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeMedium
        picker.videoMaximumDuration = 60 // 1 minute max
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: VideoCameraView

        init(_ parent: VideoCameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                parent.selectedVideoURL = videoURL
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Video Preview

struct VideoPreview: View {
    let url: URL

    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    VStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                        Text("Video Ready")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    }
                )
        }
    }
}

// MARK: - Movie Transfer Type

struct Movie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = URL.documentsDirectory.appending(path: "video_\(Date().timeIntervalSince1970).mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self.init(url: copy)
        }
    }
}

#Preview {
    ProofSubmissionModal(
        isPresented: .constant(true),
        task: TaskEntry(
            id: 1,
            habitId: 1,
            userId: 1,
            taskDescription: "Take a photo of your running shoes",
            difficultyLevel: 1.0,
            estimatedDuration: 5,
            successCriteria: "Shoes are laced up",
            celebrationMessage: "Great job!",
            easierAlternative: nil,
            harderAlternative: nil,
            proofRequirements: "Take a photo showing your feet with both running shoes laced up.",
            status: "pending",
            assignedDate: "2025-06-29",
            dueDate: "2025-06-29 10:00:00",
            completedAt: nil,
            proofType: "photo",
            proofContent: nil,
            proofValidationResult: nil,
            proofValidationConfidence: nil,
            proofFeedback: nil,
            aiGenerationMetadata: nil,
            calibrationMetadata: nil,
            createdAt: "2025-06-29 06:00:00",
            updatedAt: nil
        ),
        onSubmitProof: { _ in }
    )
}