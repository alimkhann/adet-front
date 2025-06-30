import SwiftUI
import Combine

struct UploadProofSection: View {
    let habit: Habit
    @ObservedObject var aiTaskViewModel: AITaskViewModel
    @StateObject private var state = HabitStateManager()
    @Environment(\.colorScheme) private var colorScheme
    @State private var showProofSubmissionModal = false
    @State private var timer: Timer.TimerPublisher = Timer.publish(every: 1, on: .main, in: .common)
    @State private var now: Date = Date()
    @State private var timerCancellable: Cancellable?

    // Validation states
    @State private var isValidating = false
    @State private var validationDots = "."
    @State private var validationTimer: Timer?
    @State private var showSuccessSection = false
    @State private var showFailureSection = false
    @State private var validationMessage = ""
    @State private var retryCount = 0
    private let maxRetries = 10

    @State private var hasShownCompletionFeedback = false
    @State private var hasShownFailureFeedback = false
    @State private var hasShownExpiredDismissal = false
    @State private var nextTaskTimeString = ""
    @State private var comebackMessage = ""
    @State private var permanentlyDismissedTaskId: Int? = nil

    var body: some View {
        Group {
            if let currentTask = aiTaskViewModel.currentTask, currentTask.habitId == habit.id {
                let timeRemaining = timeRemainingForTask(task: currentTask)
                let isExpired = timeRemaining <= 0 && currentTask.status == "pending"
                let isPermanentlyDismissed = permanentlyDismissedTaskId == currentTask.id

                // Debug prints to verify logic
                print("🔍 UploadProofSection Debug for task \(currentTask.id):")
                print("   - isExpired: \(isExpired)")
                print("   - hasShownExpiredDismissal: \(hasShownExpiredDismissal)")
                print("   - isPermanentlyDismissed: \(isPermanentlyDismissed)")
                print("   - nextTaskTimeString: '\(nextTaskTimeString)'")

                if isExpired && !hasShownExpiredDismissal && !isPermanentlyDismissed {
                    // ONLY show expired notification - nothing else (only once)
                    expiredTaskView(currentTask)
                } else if hasShownExpiredDismissal || isPermanentlyDismissed {
                    // Once dismissed, always show comeback message (never show task again)
                    if nextTaskTimeString.isEmpty {
                        EmptyView()
                            .onAppear {
                                calculateSmartComebackMessage()
                            }
                    } else {
                        comebackMessageView
                    }
                } else {
                    // Normal proof section flow (only for non-expired tasks)
                    normalProofSectionView
                }
            } else {
                // No task for this habit
                EmptyView()
            }
        }
        .sheet(isPresented: $showProofSubmissionModal) {
            if let currentTask = aiTaskViewModel.currentTask {
                ProofSubmissionModal(
                    isPresented: $showProofSubmissionModal,
                    task: currentTask,
                    onSubmitProof: { proofData in
                        handleProofSubmissionData(proofData)
                    }
                )
            }
        }
        .onAppear {
            timerCancellable = timer.connect()
        }
        .onDisappear {
            timerCancellable?.cancel()
            stopValidationAnimation()
        }
        .onReceive(timer) { _ in
            now = Date()
        }
    }

    private var normalProofSectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Show completion feedback exclusively
            if showSuccessSection || showFailureSection {
                VStack(alignment: .leading, spacing: 16) {
                    if showSuccessSection {
                        successCompletionView()
                    } else if showFailureSection {
                        failureCompletionView()
                    }
                }
            } else if let currentTask = aiTaskViewModel.currentTask, currentTask.habitId == habit.id {
                // Normal task view in container
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        switch currentTask.status {
                        case "pending":
                            pendingTaskView(currentTask)
                        case "completed":
                            if !hasShownCompletionFeedback {
                                EmptyView()
                                    .onAppear {
                                        showSuccessSection = true
                                        hasShownCompletionFeedback = true
                                        validationMessage = currentTask.celebrationMessage
                                    }
                            } else {
                                EmptyView()
                                    .onAppear {
                                        calculateAndShowNextTaskTime()
                                    }
                            }
                        case "failed":
                            failedTaskView(currentTask)
                        case "pending_review":
                            pendingReviewTaskView(currentTask)
                        default:
                            pendingTaskView(currentTask)
                        }
                    }
                    .padding()
                    .background(colorScheme == .dark ? Color.zinc900 : Color.zinc100)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05), lineWidth: 1)
                    )
                }
            }
        }
    }

    private func handleProofSubmissionData(_ proofData: ProofSubmissionData) {
        startValidationAnimation()

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
                    handleProofSubmission(response.task)
                    print("✅ Proof submitted successfully: \(response.message)")
                }

            } catch {
                await MainActor.run {
                    stopValidationAnimation()
                    showFailureSection = true
                    validationMessage = "Failed to submit proof. Please try again."
                    retryCount += 1
                    print("❌ Error submitting proof: \(error)")
                }
            }
        }
    }

    private func handleProofSubmission(_ task: TaskEntry) {
        stopValidationAnimation()

        if task.status == "completed" {
            showSuccessSection = true
            validationMessage = task.celebrationMessage
        } else if task.status == "failed" {
            showFailureSection = true
            validationMessage = task.proofFeedback ?? "Your proof couldn't be validated. Please try again with a clearer photo."
            retryCount += 1
        }
    }

    private func startValidationAnimation() {
        isValidating = true
        validationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            switch validationDots {
            case ".":
                validationDots = ".."
            case "..":
                validationDots = "..."
            case "...":
                validationDots = "."
            default:
                validationDots = "."
            }
        }
    }

    private func stopValidationAnimation() {
        isValidating = false
        validationTimer?.invalidate()
        validationTimer = nil
        validationDots = "."
    }

    private func pendingTaskView(_ task: TaskEntry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            let timeRemaining = timeRemainingForTask(task: task)

            // Normal pending task view (expired logic moved outside)
            VStack(alignment: .leading, spacing: 12) {
                // Task description
                Text(task.taskDescription)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colorScheme == .dark ? Color.black : Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 1)
                    )

                // Proof requirements
                Text(task.proofRequirements)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colorScheme == .dark ? Color.black : Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 1)
                    )

                // Timer display - full width
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .foregroundColor(timerIconColor(for: timeRemaining))
                    Text(formatTimeRemaining(timeRemaining))
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(timerColor(for: timeRemaining))
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(timerBackgroundColor(for: timeRemaining))
                .cornerRadius(10)
                .animation(.easeInOut, value: timeRemaining)

                if isValidating {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Validating\(validationDots)")
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                } else {
                    Button("Submit Proof") {
                        showProofSubmissionModal = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
    }

    private func successCompletionView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Success header with celebration
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    Text("Amazing! 🎉")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }

                Text("Task completed successfully!")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            // Celebration message
            Text(validationMessage)
                .font(.body)
                .foregroundColor(.primary)

            if !nextTaskTimeString.isEmpty {
                Text("Next task: \(nextTaskTimeString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }

            Button("Continue") {
                showSuccessSection = false
                hasShownCompletionFeedback = true
                calculateAndShowNextTaskTime()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .background(Color.clear)
    }

    private func failureCompletionView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Failure header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Validation Failed")
                    .font(.headline)
                    .foregroundColor(.orange)
            }

            // Failure message
            Text(validationMessage)
                .font(.body)
                .foregroundColor(.primary)

            // Encouraging message
            Text("No worries! Every attempt is progress. You're building resilience! 💪")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)

            // Retry info
            Text("Attempts: \(retryCount)/\(maxRetries)")
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                if retryCount < maxRetries {
                    Button("Try Again") {
                        showFailureSection = false
                        showProofSubmissionModal = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Button("Dismiss") {
                    showFailureSection = false
                    if retryCount >= maxRetries {
                        // Max retries reached, mark as failed
                        markTaskAsFailed()
                    }
                    showNextTaskTime()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
    }

    private func completedTaskView(_ task: TaskEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Completed")
                    .font(.headline)
                    .foregroundColor(.green)
            }

            if let completedAt = task.completedAt {
                Text("Completed at \(formatCompletionTime(completedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(task.celebrationMessage)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    private func failedTaskView(_ task: TaskEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("Task Failed")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            Text("Don't give up! Tomorrow is a new opportunity to build this habit.")
                .font(.body)
                .foregroundColor(.secondary)

            Button("I'll try tomorrow") {
                showNextTaskTime()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }

    private func pendingReviewTaskView(_ task: TaskEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Under Review")
                    .font(.headline)
            }

            Text("Your proof is being validated. This usually takes a few moments.")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func showNextTaskTime() {
        calculateAndShowNextTaskTime()
    }

    private func calculateAndShowNextTaskTime() {
        // Parse the validation time from the habit
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()

        if let validationTime = timeFormatter.date(from: habit.validationTime) {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: validationTime)
            let nextTaskDate = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                           minute: timeComponents.minute ?? 0,
                                           second: 0,
                                           of: tomorrow)

            if let nextDate = nextTaskDate {
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "EEEE 'at' h:mm a"
                nextTaskTimeString = displayFormatter.string(from: nextDate)
            } else {
                nextTaskTimeString = "Tomorrow at \(habit.validationTime)"
            }
        } else {
            nextTaskTimeString = "Tomorrow at \(habit.validationTime)"
        }
    }

    // MARK: - Helper Methods

    private func timeRemainingForTask(task: TaskEntry) -> TimeInterval {
        var dueDateString = task.dueDate
        if !dueDateString.contains("Z") && !dueDateString.contains("+") {
            dueDateString += "Z"
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let dueDate = formatter.date(from: dueDateString) else {
            return 0
        }
        return dueDate.timeIntervalSince(now)
    }

    private func timerColor(for timeInterval: TimeInterval) -> Color {
        if timeInterval <= 1800 && timeInterval > 0 {
            return .red
        } else {
            return Color(UIColor.label).opacity(0.7)
        }
    }

    private func timerBackgroundColor(for timeInterval: TimeInterval) -> Color {
        if timeInterval <= 1800 && timeInterval > 0 {
            return Color.red.opacity(0.15)
        } else {
            return Color(.systemGray6)
        }
    }

    private func timerIconColor(for timeInterval: TimeInterval) -> Color {
        if timeInterval <= 1800 && timeInterval > 0 {
            return .red
        } else {
            return Color(UIColor.label).opacity(0.7)
        }
    }

    private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = max(Int(timeInterval), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02dh %02dm %02ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%02dm %02ds", minutes, seconds)
        } else {
            return String(format: "%02ds", seconds)
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

    private func markTaskAsFailed() {
        guard let currentTask = aiTaskViewModel.currentTask else { return }

        // Create a new task object with failed status
        let failedTask = TaskEntry(
            id: currentTask.id,
            habitId: currentTask.habitId,
            userId: currentTask.userId,
            taskDescription: currentTask.taskDescription,
            difficultyLevel: currentTask.difficultyLevel,
            estimatedDuration: currentTask.estimatedDuration,
            successCriteria: currentTask.successCriteria,
            celebrationMessage: currentTask.celebrationMessage,
            easierAlternative: currentTask.easierAlternative,
            harderAlternative: currentTask.harderAlternative,
            proofRequirements: currentTask.proofRequirements,
            status: "failed",
            assignedDate: currentTask.assignedDate,
            dueDate: currentTask.dueDate,
            completedAt: currentTask.completedAt,
            proofType: currentTask.proofType,
            proofContent: currentTask.proofContent,
            proofValidationResult: currentTask.proofValidationResult,
            proofValidationConfidence: currentTask.proofValidationConfidence,
            proofFeedback: currentTask.proofFeedback,
            aiGenerationMetadata: currentTask.aiGenerationMetadata,
            calibrationMetadata: currentTask.calibrationMetadata,
            createdAt: currentTask.createdAt,
            updatedAt: currentTask.updatedAt
        )

        aiTaskViewModel.currentTask = failedTask
    }

    private func expiredTaskView(_ task: TaskEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // X mark in top right corner
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock.badge.xmark")
                            .foregroundColor(.red)
                        Text("Time Expired")
                            .font(.headline)
                            .foregroundColor(.red)
                    }

                    Text("Don't worry! Tomorrow is a fresh start. You've got this!")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    hasShownExpiredDismissal = true
                    permanentlyDismissedTaskId = task.id
                    markTaskAsFailed()
                    // Immediately calculate comeback message
                    calculateSmartComebackMessage()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }

    private var comebackMessageView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.blue)
                Text(comebackMessage)
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            Text(nextTaskTimeString)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }

    private func calculateSmartComebackMessage() {
        let calendar = Calendar.current
        let now = Date()

        // Parse the validation time from the habit
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        // Calculate next task based on frequency
        let nextTaskDate: Date

        switch habit.frequency.lowercased() {
        case "daily", "every day":
            // Daily habits: next occurrence is tomorrow
            nextTaskDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            comebackMessage = calendar.isDateInToday(now) ? "Come back tomorrow!" : "Come back soon!"

        case "weekly", "every week":
            // Weekly habits: next occurrence is in a week
            nextTaskDate = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
            comebackMessage = "See you next week!"

        default:
            // Custom frequency: fallback to tomorrow
            nextTaskDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            comebackMessage = "Come back soon!"
        }

        // Set the specific time
        if let validationTime = timeFormatter.date(from: habit.validationTime) {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: validationTime)
            let finalDate = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                        minute: timeComponents.minute ?? 0,
                                        second: 0,
                                        of: nextTaskDate)

            if let finalDate = finalDate {
                let displayFormatter = DateFormatter()

                // Different formats based on how far away it is
                let daysDifference = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: finalDate)).day ?? 0

                if daysDifference == 1 {
                    displayFormatter.dateFormat = "'Tomorrow at' h:mm a"
                } else if daysDifference <= 7 {
                    displayFormatter.dateFormat = "EEEE 'at' h:mm a"
                } else {
                    displayFormatter.dateFormat = "MMM d 'at' h:mm a"
                }

                nextTaskTimeString = displayFormatter.string(from: finalDate)
            } else {
                nextTaskTimeString = "Tomorrow at \(habit.validationTime)"
            }
        } else {
            nextTaskTimeString = "Tomorrow at \(habit.validationTime)"
        }
    }
}
