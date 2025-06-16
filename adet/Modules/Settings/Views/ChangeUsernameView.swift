import SwiftUI

struct ChangeUsernameView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var newUsername: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showSuccessAlert: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("New Username")) {
                    TextField("Enter new username", text: $newUsername)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                if let error = authViewModel.authError {
                    Text(error)
                        .foregroundStyle(.red)
                }

                LoadingButton(
                    title: "Change Username",
                    isLoading: authViewModel.isLoading
                ) {
                    Task {
                        authViewModel.updateUsername(newUsername: newUsername)
                        if authViewModel.authError == nil {
                            showSuccessAlert = true
                        } else {
                            alertMessage = authViewModel.authError ?? "An unknown error occurred."
                            showAlert = true
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(newUsername.isEmpty || authViewModel.isLoading)
            }
            .navigationTitle("Change Username")
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
                Text("Your username has been successfully updated.")
            }
        }
    }
}

struct ChangeUsernameView_Previews: PreviewProvider {
    static var previews: some View {
        ChangeUsernameView()
            .environmentObject(AuthViewModel(authService: AuthenticationService()))
    }
}
