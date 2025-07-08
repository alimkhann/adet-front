import SwiftUI
import OSLog

struct ReportUserView: View {
    let userId: Int
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: ReportReason?
    @State private var customReason = ""
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false

    private let logger = Logger(subsystem: "com.adet.friends", category: "ReportUserView")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Report User")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Help us understand what's happening with this account. Your report is anonymous.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Preset reasons
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Why are you reporting this account?")
                            .font(.headline)

                        ForEach(ReportReason.allCases, id: \.self) { reason in
                            ReportReasonRow(
                                reason: reason,
                                isSelected: selectedReason == reason,
                                onTap: {
                                    selectedReason = reason
                                }
                            )
                        }
                    }

                    // Custom reason
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional details (optional)")
                            .font(.headline)

                        TextField("Please provide more details...", text: $customReason, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    Spacer(minLength: 32)
                }
                .padding()
            }
            .navigationTitle("Report User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            await submitReport()
                        }
                    }
                    .disabled(selectedReason == nil || isSubmitting)
                }
            }
        }
        .alert("Report Submitted", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Thank you for your report. We'll review it and take appropriate action.")
        }
    }

    private func submitReport() async {
        guard let reason = selectedReason else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let viewModel = FriendsViewModel()
        let success = await viewModel.reportUser(
            userId: userId,
            category: reason.rawValue,
            description: customReason.isEmpty ? nil : customReason
        )

        if success {
            showSuccessAlert = true
        }
    }
}

// MARK: - Report Reason

enum ReportReason: String, CaseIterable {
    case spam = "spam"
    case harassment = "harassment"
    case inappropriateContent = "inappropriate_content"
    case falseInformation = "false_information"
    case hateSpeech = "hate_speech"
    case impersonation = "impersonation"
    case other = "other"

    var displayName: String {
        switch self {
        case .spam:
            return "Spam"
        case .harassment:
            return "Harassment or bullying"
        case .inappropriateContent:
            return "Inappropriate content"
        case .falseInformation:
            return "False information"
        case .hateSpeech:
            return "Hate speech"
        case .impersonation:
            return "Impersonation"
        case .other:
            return "Other"
        }
    }

    var description: String {
        switch self {
        case .spam:
            return "Unwanted commercial content or repeated messages"
        case .harassment:
            return "Targeting someone with unwelcome behavior"
        case .inappropriateContent:
            return "Content that violates community guidelines"
        case .falseInformation:
            return "Sharing misleading or false information"
        case .hateSpeech:
            return "Content that attacks people based on identity"
        case .impersonation:
            return "Pretending to be someone else"
        case .other:
            return "Something else that violates our guidelines"
        }
    }
}

// MARK: - Report Reason Row

struct ReportReasonRow: View {
    let reason: ReportReason
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(reason.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(reason.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ReportUserView(userId: 123)
}
