import SwiftUI

struct AITaskDisplayView: View {
    let task: TaskEntry
    @StateObject private var viewModel = AITaskViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Task Header
                    taskHeaderSection

                    // Task Details
                    taskDetailsSection

                    // Success Criteria
                    successCriteriaSection

                    // Proof Requirements
                    proofRequirementsSection

                    // Action Buttons
                    actionButtonsSection

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Today's Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showProofSubmission) {
                proofSubmissionSheet
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(viewModel.successMessage)
            }
        }
    }

    private var taskHeaderSection: some View {
        VStack(spacing: 16) {
            // Status Badge
            HStack {
                Circle()
                    .fill(viewModel.getStatusColor(task.status))
                    .frame(width: 12, height: 12)

                Text(TaskStatus(rawValue: task.status)?.displayName ?? task.status.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(viewModel.getStatusColor(task.status))

                Spacer()
            }

            // Task Description
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "target")
                        .foregroundColor(.blue)
                    Text("Your Task")
                        .font(.headline)
                    Spacer()
                }

                Text(task.taskDescription)
                    .font(.body)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }

            // Difficulty and Duration
            HStack(spacing: 20) {
                VStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.orange)
                    Text(viewModel.formatDifficulty(task.difficultyLevel))
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Difficulty")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.green)
                    Text(viewModel.formatDuration(task.estimatedDuration))
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Duration")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
    }

    private var taskDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Task Details")
                .font(.headline)

            VStack(spacing: 12) {
                if let easierAlternative = task.easierAlternative {
                    detailRow(
                        icon: "arrow.down.circle",
                        title: "Easier Alternative",
                        content: easierAlternative,
                        color: .green
                    )
                }

                if let harderAlternative = task.harderAlternative {
                    detailRow(
                        icon: "arrow.up.circle",
                        title: "Harder Alternative",
                        content: harderAlternative,
                        color: .red
                    )
                }
            }
        }
    }

    private var successCriteriaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Success Criteria")
                    .font(.headline)
            }

            Text(task.successCriteria)
                .font(.body)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
        }
    }

    private var proofRequirementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundColor(.blue)
                Text("Proof Requirements")
                    .font(.headline)
            }

            Text(task.proofRequirements)
                .font(.body)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
        }
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if task.status == "pending" {
                Button(action: {
                    viewModel.showProofSubmission = true
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Submit Proof")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.updateTaskStatus(.failed)
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Failed")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    Button(action: {
                        viewModel.updateTaskStatus(.missed)
                    }) {
                        HStack {
                            Image(systemName: "clock.badge.xmark")
                            Text("Missed")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            } else {
                // Show celebration message for completed tasks
                if task.status == "completed" {
                    VStack(spacing: 12) {
                        Image(systemName: "party.popper.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.yellow)

                        Text(task.celebrationMessage)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
            }
        }
    }

    private var proofSubmissionSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Proof Type Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select Proof Type")
                        .font(.headline)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                                    ForEach(TaskProofType.allCases, id: \.self) { proofType in
                            Button(action: {
                                viewModel.selectedProofType = proofType
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: proofType.icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(viewModel.selectedProofType == proofType ? .blue : .gray)

                                    Text(proofType.displayName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(viewModel.selectedProofType == proofType ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                // Proof Content Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Proof Content")
                        .font(.headline)

                    TextField("Describe what you did...", text: $viewModel.proofContent, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(4...6)
                }

                Spacer()

                // Submit Button
                Button(action: {
                    viewModel.submitTaskProof()
                }) {
                    HStack {
                        if viewModel.isSubmittingProof {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }

                        Text(viewModel.isSubmittingProof ? "Submitting..." : "Submit Proof")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isSubmittingProof || viewModel.proofContent.isEmpty)
                .opacity((viewModel.isSubmittingProof || viewModel.proofContent.isEmpty) ? 0.6 : 1.0)
            }
            .padding()
            .navigationTitle("Submit Proof")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.showProofSubmission = false
                    }
                }
            }
        }
    }

    private func detailRow(icon: String, title: String, content: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Text(content)
                    .font(.body)
            }

            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    AITaskDisplayView(task: TaskEntry(
        id: 1,
        habitId: 1,
        userId: 1,
        taskDescription: "Do 5 push-ups right after you wake up",
        difficultyLevel: 1.5,
        estimatedDuration: 2,
        successCriteria: "Complete 5 push-ups with proper form",
        celebrationMessage: "Hell yeah! You crushed those push-ups! 💪",
        easierAlternative: "Do 2 push-ups",
        harderAlternative: "Do 10 push-ups",
        proofRequirements: "Take a photo of yourself doing push-ups",
        status: "pending",
        assignedDate: "2024-01-15",
        dueDate: "2024-01-15",
        completedAt: nil,
        proofType: nil,
        proofContent: nil,
        proofValidationResult: nil,
        proofValidationConfidence: nil,
        proofFeedback: nil,
        aiGenerationMetadata: nil,
        calibrationMetadata: nil,
        createdAt: "2024-01-15T08:00:00Z",
        updatedAt: nil
    ))
}


