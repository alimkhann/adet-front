import SwiftUI

struct ResetPasswordView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSuccessAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Current Password")) {
                    SecureField("Enter current password", text: $currentPassword)
                }

                Section(header: Text("New Password")) {
                    SecureField("Enter new password", text: $newPassword)
                    SecureField("Confirm new password", text: $confirmNewPassword)
                }

                if let error = authViewModel.authError {
                    Text(error)
                        .foregroundStyle(.red)
                }

                LoadingButton(
                    title: "Reset Password",
                    isLoading: authViewModel.isLoading
                ) {
                    Task {
                        if newPassword != confirmNewPassword {
                            alertMessage = "New password and confirmation do not match."
                            showAlert = true
                            return
                        }

                        authViewModel.updatePassword(currentPassword: currentPassword, newPassword: newPassword)
                        if authViewModel.authError == nil {
                            showSuccessAlert = true
                        } else {
                            alertMessage = authViewModel.authError ?? "An unknown error occurred."
                            showAlert = true
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(currentPassword.isEmpty || newPassword.isEmpty || confirmNewPassword.isEmpty || authViewModel.isLoading)
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your password has been successfully reset.")
            }
        }
    }
}

struct ResetPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ResetPasswordView()
            .environmentObject(AuthViewModel(authService: AuthenticationService()))
    }
}
