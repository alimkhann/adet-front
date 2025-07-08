import SwiftUI
import MessageUI

struct ContactSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: SupportCategory = .general
    @State private var subject = ""
    @State private var message = ""
    @State private var includeSystemInfo = true
    @State private var isSubmitting = false
    @State private var showEmailComposer = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @AppStorage("appLanguage") var appLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"

    var body: some View {
        NavigationView {
            Form {
                // Category Selection
                Section(header: Text("support_category".t(appLanguage))) {
                    Picker("category".t(appLanguage), selection: $selectedCategory) {
                        ForEach(SupportCategory.allCases, id: \.self) { category in
                            Text(category.displayName.t(appLanguage))
                                .tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                // Subject
                Section(header: Text("subject".t(appLanguage))) {
                    TextField("subject_placeholder".t(appLanguage), text: $subject)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                // Message
                Section(header: Text("message".t(appLanguage))) {
                    TextField("message_placeholder".t(appLanguage), text: $message, axis: .vertical)
                        .lineLimit(5...10)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                // System Info Toggle
                Section {
                    Toggle("include_system_info".t(appLanguage), isOn: $includeSystemInfo)
                } footer: {
                    Text("system_info_description".t(appLanguage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Submit Button
                Section {
                    Button(action: submitSupportRequest) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }

                            Text(isSubmitting ? "sending".t(appLanguage) : "send_message".t(appLanguage))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isSubmitting || subject.isEmpty || message.isEmpty)
                }

                // Alternative Contact Methods
                Section(header: Text("alternative_contact".t(appLanguage))) {
                    Button(action: openEmailComposer) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                            Text("send_email".t(appLanguage))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://t.me/adet_support")!) {
                        HStack {
                            Image(systemName: "message.fill")
                                .foregroundColor(.blue)
                            Text("telegram_support".t(appLanguage))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("contact_support".t(appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".t(appLanguage)) {
                        dismiss()
                    }
                }
            }
        }
        .alert("success".t(appLanguage), isPresented: $showSuccessAlert) {
            Button("ok".t(appLanguage)) {
                dismiss()
            }
        } message: {
            Text("support_message_sent".t(appLanguage))
        }
        .alert("error".t(appLanguage), isPresented: $showErrorAlert) {
            Button("ok".t(appLanguage)) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showEmailComposer) {
            EmailComposerView(
                to: "support@adet.app",
                subject: subject.isEmpty ? selectedCategory.emailSubject.t(appLanguage) : subject,
                body: createEmailBody()
            )
        }
    }

    private func submitSupportRequest() {
        guard !subject.isEmpty && !message.isEmpty else { return }

        isSubmitting = true

        // Try to submit via API first
        Task {
            let success = await SupportService.shared.submitSupportRequest(
                category: selectedCategory.rawValue,
                subject: subject,
                message: message,
                includeSystemInfo: includeSystemInfo
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

    private func createEmailBody() -> String {
        var body = message

        if includeSystemInfo {
            body += "\n\n--- System Information ---\n"
            body += "App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")\n"
            body += "iOS Version: \(UIDevice.current.systemVersion)\n"
            body += "Device: \(UIDevice.current.model)\n"
            body += "Language: \(appLanguage)\n"
            body += "Category: \(selectedCategory.displayName.t(appLanguage))"
        }

        return body
    }
}

// MARK: - Support Categories

enum SupportCategory: String, CaseIterable {
    case general = "general"
    case technical = "technical"
    case billing = "billing"
    case feature = "feature"
    case bug = "bug"
    case account = "account"
    case privacy = "privacy"

    var displayName: String {
        switch self {
        case .general: return "general_support"
        case .technical: return "technical_support"
        case .billing: return "billing_support"
        case .feature: return "feature_request"
        case .bug: return "bug_report"
        case .account: return "account_support"
        case .privacy: return "privacy_support"
        }
    }

    var emailSubject: String {
        switch self {
        case .general: return "General Support Request"
        case .technical: return "Technical Support Request"
        case .billing: return "Billing Support Request"
        case .feature: return "Feature Request"
        case .bug: return "Bug Report"
        case .account: return "Account Support Request"
        case .privacy: return "Privacy Support Request"
        }
    }
}

// MARK: - Email Composer

struct EmailComposerView: UIViewControllerRepresentable {
    let to: String
    let subject: String
    let body: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([to])
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}

#Preview {
    ContactSupportView()
}