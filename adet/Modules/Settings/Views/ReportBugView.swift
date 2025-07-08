import SwiftUI
import MessageUI

struct ReportBugView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bugTitle = ""
    @State private var bugDescription = ""
    @State private var stepsToReproduce = ""
    @State private var expectedBehavior = ""
    @State private var actualBehavior = ""
    @State private var selectedSeverity: BugSeverity = .medium
    @State private var selectedCategory: BugCategory = .general
    @State private var includeSystemInfo = true
    @State private var includeScreenshots = false
    @State private var isSubmitting = false
    @State private var showEmailComposer = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                categorySection
                severitySection
                titleSection
                descriptionSection
                stepsSection
                behaviorSection
                additionalOptionsSection
                submitSection
                alternativeContactSection
            }
            .navigationTitle("report_bug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("success", isPresented: $showSuccessAlert) {
            Button("ok") {
                dismiss()
            }
        } message: {
            Text("bug_report_sent")
        }
        .alert("error", isPresented: $showErrorAlert) {
            Button("ok") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showEmailComposer) {
            EmailComposerView(
                to: "bugs@adet.app",
                subject: emailSubject,
                body: createBugReportEmail()
            )
        }
    }

    private var emailSubject: String {
        bugTitle.isEmpty ? "Bug Report - \(selectedCategory.displayName)" : "Bug Report: \(bugTitle)"
    }

    private var categorySection: some View {
        Section(header: Text("bug_category")) {
            Picker("category", selection: $selectedCategory) {
                ForEach(BugCategory.allCases, id: \.self) { category in
                    Text(category.displayName)
                        .tag(category)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }

    private var severitySection: some View {
        Section(header: Text("bug_severity")) {
            Picker("severity", selection: $selectedSeverity) {
                ForEach(BugSeverity.allCases, id: \.self) { severity in
                    HStack {
                        Circle()
                            .fill(severity.color)
                            .frame(width: 12, height: 12)
                        Text(severity.displayName)
                    }
                    .tag(severity)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }

    private var titleSection: some View {
        Section(header: Text("bug_title")) {
            TextField("bug_title_placeholder", text: $bugTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }

    private var descriptionSection: some View {
        Section(header: Text("bug_description")) {
            TextField("bug_description_placeholder", text: $bugDescription, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }

    private var stepsSection: some View {
        Section(header: Text("steps_to_reproduce")) {
            TextField("steps_placeholder", text: $stepsToReproduce, axis: .vertical)
                .lineLimit(3...8)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }

    private var behaviorSection: some View {
        Section(header: Text("behavior_comparison")) {
            TextField("expected_behavior_placeholder", text: $expectedBehavior, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("actual_behavior_placeholder", text: $actualBehavior, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }

    private var additionalOptionsSection: some View {
        Section {
            Toggle("include_system_info", isOn: $includeSystemInfo)
            Toggle("include_screenshots", isOn: $includeScreenshots)
        } header: {
            Text("additional_info")
        } footer: {
            Text("additional_info_description")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var submitSection: some View {
        Section {
            Button(action: submitBugReport) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }

                    Text(isSubmitting ? "sending" : "submit_bug_report")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isSubmitting || bugTitle.isEmpty || bugDescription.isEmpty)
        }
    }

    private var alternativeContactSection: some View {
        Section(header: Text("alternative_contact")) {
            Button(action: openEmailComposer) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.blue)
                    Text("send_email")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Link(destination: URL(string: "https://github.com/adet-app/issues")!) {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.blue)
                    Text("github_issues")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func submitBugReport() {
        guard !bugTitle.isEmpty && !bugDescription.isEmpty else { return }

        isSubmitting = true

        // Try to submit via API first
        Task {
            let success = await SupportService.shared.submitBugReport(
                category: selectedCategory.rawValue,
                severity: selectedSeverity.rawValue,
                title: bugTitle,
                description: bugDescription,
                stepsToReproduce: stepsToReproduce,
                expectedBehavior: expectedBehavior,
                actualBehavior: actualBehavior,
                includeSystemInfo: includeSystemInfo,
                includeScreenshots: includeScreenshots
            )

            await MainActor.run {
                isSubmitting = false

                if success {
                    showSuccessAlert = true
                } else {
                    // Fallback to email
                    showEmailComposer = true
                }
            }
        }
    }

    private func openEmailComposer() {
        showEmailComposer = true
    }

    private func createBugReportEmail() -> String {
        var body = "Bug Report\n\n"
        body += "Title: \(bugTitle)\n"
        body += "Category: \(selectedCategory.displayName)\n"
        body += "Severity: \(selectedSeverity.displayName)\n\n"
        body += "Description:\n\(bugDescription)\n\n"

        if !stepsToReproduce.isEmpty {
            body += "Steps to Reproduce:\n\(stepsToReproduce)\n\n"
        }

        if !expectedBehavior.isEmpty {
            body += "Expected Behavior:\n\(expectedBehavior)\n\n"
        }

        if !actualBehavior.isEmpty {
            body += "Actual Behavior:\n\(actualBehavior)\n\n"
        }

        if includeSystemInfo {
            body += "--- System Information ---\n"
            body += "App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")\n"
            body += "iOS Version: \(UIDevice.current.systemVersion)\n"
            body += "Device: \(UIDevice.current.model)\n"
        }

        return body
    }
}

// MARK: - Bug Categories

enum BugCategory: String, CaseIterable {
    case general = "general"
    case ui = "ui"
    case performance = "performance"
    case crash = "crash"
    case authentication = "authentication"
    case habits = "habits"
    case friends = "friends"
    case chat = "chat"
    case notifications = "notifications"

    var displayName: String {
        switch self {
        case .general: return "general_bug"
        case .ui: return "ui_bug"
        case .performance: return "performance_issue"
        case .crash: return "app_crash"
        case .authentication: return "authentication_issue"
        case .habits: return "habits_feature"
        case .friends: return "friends_feature"
        case .chat: return "chat_feature"
        case .notifications: return "notifications_issue"
        }
    }
}

// MARK: - Bug Severity

enum BugSeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    var displayName: String {
        switch self {
        case .low: return "low_severity"
        case .medium: return "medium_severity"
        case .high: return "high_severity"
        case .critical: return "critical_severity"
        }
    }

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

#Preview {
    ReportBugView()
}
