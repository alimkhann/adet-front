import SwiftUI

struct DeleteAccountView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Delete Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)

                Text("Are you sure you want to delete your account? This action cannot be undone.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let error = authViewModel.authError {
                    Text(error)
                        .foregroundStyle(.red)
                }

                LoadingButton(
                    title: "Confirm Delete Account",
                    isLoading: authViewModel.isLoading
                ) {
                    Task {
                        authViewModel.deleteAccount()
                        if authViewModel.authError != nil {
                            alertMessage = authViewModel.authError ?? "An unknown error occurred."
                            showAlert = true
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .tint(.red)

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .alert("Error", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .alert("Account Deleted", isPresented: $authViewModel.showAccountDeletedAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your account has been successfully deleted.")
            }
        }
    }
}

struct DeleteAccountView_Previews: PreviewProvider {
    static var previews: some View {
        DeleteAccountView()
            .environmentObject(AuthViewModel(authService: AuthenticationService()))
    }
}
