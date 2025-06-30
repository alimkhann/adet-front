import SwiftUI

struct UploadProofSection: View {
    let habit: Habit
    let aiTaskViewModel: AITaskViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showProofSubmissionModal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Only show upload proof for pending tasks
            if let currentTask = aiTaskViewModel.currentTask,
               currentTask.habitId == habit.id {

                switch currentTask.status {
                case "pending":
                    pendingTaskView(currentTask)
                case "completed":
                    completedTaskView(currentTask)
                case "failed":
                    failedTaskView(currentTask)
                case "pending_review":
                    pendingReviewTaskView(currentTask)
                default:
                    pendingTaskView(currentTask)
                }
            }
        }
        .sheet(isPresented: $showProofSubmissionModal) {
            if let currentTask = aiTaskViewModel.currentTask {
                ProofSubmissionModal(
                    isPresented: $showProofSubmissionModal,
                    task: currentTask,
                    onSubmitProof: handleProofSubmission
                )
            }
        }
    }

    // MARK: - Task Status Views

    private func pendingTaskView(_ task: TaskEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Upload Proof")
                .font(.title2)
                .fontWeight(.bold)

            // Proof Requirements
            VStack(alignment: .leading, spacing: 8) {
                Text(task.proofRequirements)
                    .font(.body)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }

            // Timer Section
            timerSection(for: task)

            // Upload Button
            Button(action: {
                showProofSubmissionModal = true
            }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Submit Proof")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }

    private func completedTaskView(_ task: TaskEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Success Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                Text("Task Completed!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }

            // Celebration Message
            if !task.celebrationMessage.isEmpty {
                Text(task.celebrationMessage)
                    .font(.body)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
            }

            // Completion Details
            VStack(alignment: .leading, spacing: 8) {
                if let completedAt = task.completedAt {
                    Text("Completed: \(formatCompletionTime(completedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let feedback = task.proofFeedback {
                    Text("Feedback: \(feedback)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    private func failedTaskView(_ task: TaskEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Failed Header
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.title2)
                Text("Task Failed")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }

            // Feedback
            if let feedback = task.proofFeedback {
                Text(feedback)
                    .font(.body)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
            }

            // Try Again Button
            Button(action: {
                showProofSubmissionModal = true
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    private func pendingReviewTaskView(_ task: TaskEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Pending Review Header
            HStack {
                Image(systemName: "clock.badge.questionmark")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Under Review")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }

            // Review Message
            Text("Your proof has been submitted and is being reviewed. You'll be notified once it's validated.")
                .font(.body)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)

            if let feedback = task.proofFeedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Helper Views

    private func timerSection(for task: TaskEntry) -> some View {
        let timeRemaining = timeRemainingForTask(task: task)
        let isExpired = timeRemaining <= 0

        return HStack {
            Image(systemName: isExpired ? "clock.badge.xmark" : "clock")
                .foregroundColor(isExpired ? .red : .orange)

            if isExpired {
                Text("Time expired")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Text("Time remaining: \(formatTimeRemaining(timeRemaining))")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isExpired ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Helper Methods

    private func handleProofSubmission(_ proofData: ProofSubmissionData) {
        Task {
            do {
                // Use the proper API service for authenticated requests
                let apiService = APIService.shared

                // Prepare file data based on proof type
                var fileData: Data?
                var fileName: String?
                var mimeType: String?

                switch proofData.proofType {
                case .photo:
                    if let image = proofData.image {
                        fileData = image.jpegData(compressionQuality: 0.8)
                        fileName = "proof.jpg"
                        mimeType = "image/jpeg"
                    }
                case .video:
                    if let videoURL = proofData.videoURL {
                        fileData = try Data(contentsOf: videoURL)
                        fileName = "proof.mp4"
                        mimeType = "video/mp4"
                    }
                case .audio:
                    if let audioURL = proofData.audioURL {
                        fileData = try Data(contentsOf: audioURL)
                        fileName = "proof.m4a"
                        mimeType = "audio/mp4"
                    }
                case .text:
                    // No file data for text proofs
                    break
                }

                let response = try await apiService.submitTaskProofWithFile(
                    taskId: proofData.taskId,
                    proofType: proofData.proofType.rawValue,
                    proofContent: proofData.proofContent,
                    fileData: fileData,
                    fileName: fileName,
                    mimeType: mimeType
                )

                await MainActor.run {
                    // Update the current task with the response
                    aiTaskViewModel.currentTask = response.task

                    // Show success/failure message
                    print("✅ Proof submitted successfully: \(response.message)")
                }

            } catch {
                await MainActor.run {
                    print("❌ Error submitting proof: \(error)")
                }
            }
        }
    }

    private func timeRemainingForTask(task: TaskEntry) -> TimeInterval {
        let formatter = ISO8601DateFormatter()
        guard let dueDate = formatter.date(from: task.dueDate) else {
            return 0
        }
        return dueDate.timeIntervalSinceNow
    }

    private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval.truncatingRemainder(dividingBy: 3600)) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatCompletionTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .none
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}
