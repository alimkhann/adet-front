import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var showChangeUsernameSheet = false
    @State private var showResetPasswordSheet = false
    @State private var showDeleteAccountSheet = false
    @State private var showDeleteAccountAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                if let user = authViewModel.user {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.username)
                                .font(.headline)
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Account")
                    }
                }
                
                Button {
                    showChangeUsernameSheet = true
                } label: {
                    Label("Change Username", systemImage: "person.text.rectangle")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button {
                    showResetPasswordSheet = true
                } label: {
                    Label("Reset Password", systemImage: "key.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button {
                    authViewModel.signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryButtonStyle())
                .foregroundStyle(.primary)
                
                Button(role: .destructive) {
                    showDeleteAccountSheet = true
                } label: {
                    Label("Delete Account", systemImage: "trash")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .sheet(isPresented: $showChangeUsernameSheet) {
                ChangeUsernameView()
            }
            .sheet(isPresented: $showResetPasswordSheet) {
                ResetPasswordView()
            }
            .sheet(isPresented: $showDeleteAccountSheet) {
                DeleteAccountView()
            }
        }
    }
}
