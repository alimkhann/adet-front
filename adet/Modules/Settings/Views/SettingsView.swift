import SwiftUI
import Clerk

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(Clerk.self) private var clerk
    @State private var isEditingUsername = false
    @State private var newUsername = ""
    @State private var showDeleteAlert = false
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            List {
                if let user = authViewModel.user {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(user.email)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            if isEditingUsername {
                                VStack(spacing: 12) {
                                    HStack {
                                        StyledTextField(
                                            placeholder: "Username",
                                            text: $newUsername
                                        )
                                        .disabled(authViewModel.isUpdatingUsername)

                                        if authViewModel.isUpdatingUsername {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                                .scaleEffect(0.8)
                                        }
                                    }

                                    HStack(spacing: 12) {
                                        Button {
                                            Task {
                                                await authViewModel.updateUsername(newUsername)
                                                if authViewModel.clerkError == nil {
                                                    isEditingUsername = false
                                                }
                                            }
                                        } label: {
                                            Text("Save")
                                                .frame(minHeight: 36)
                                        }
                                        .buttonStyle(PrimaryButtonStyle())
                                        .disabled(newUsername.isEmpty || authViewModel.isUpdatingUsername)
                                        .allowsHitTesting(!authViewModel.isUpdatingUsername)

                                        Button {
                                            newUsername = user.username ?? ""
                                            isEditingUsername = false
                                            authViewModel.clerkError = nil
                                        } label: {
                                            Text("Cancel")
                                                .frame(minHeight: 36)
                                        }
                                        .buttonStyle(SecondaryButtonStyle())
                                        .disabled(authViewModel.isUpdatingUsername)
                                    }
                                }
                            } else {
                                HStack {
                                    Text(user.username ?? "No username set")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button {
                                        newUsername = user.username ?? ""
                                        isEditingUsername = true
                                        authViewModel.clerkError = nil
                                    } label: {
                                        Image(systemName: "square.and.pencil")
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }

                            if let error = authViewModel.clerkError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Account")
                    }
                } else {
                    Section {
                        Text("User data not available")
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Account")
                    }
                }

                Section {
                    Button {
                        showSignOutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.orange)
                            Text("Sign Out")
                                .foregroundColor(.orange)
                            Spacer()
                        }
                    }
                    .disabled(authViewModel.isSigningOut)
                    .accessibilityIdentifier("SignOut")

                    Button {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            if authViewModel.isDeletingAccount {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            Text("Delete Account")
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(authViewModel.isDeletingAccount)
                    .accessibilityIdentifier("DeleteAccount")
                } header: {
                    Text("Actions")
                }

                Section {
                    Button {
                        Task {
                            await authViewModel.testNetworkConnectivity()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "network")
                                .foregroundColor(.primary)
                            Text("Test Network Connection")
                                .foregroundColor(.primary)
                            Spacer()
                            if authViewModel.isTestingNetwork {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(authViewModel.isTestingNetwork)

                    if let networkStatus = authViewModel.networkStatus {
                        HStack {
                            Image(systemName: networkStatus ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(networkStatus ? .green : .red)
                            Text(networkStatus ? "Connection OK" : "Connection Failed")
                                .foregroundColor(networkStatus ? .green : .red)
                            Spacer()
                        }
                    }
                } header: {
                    Text("Network Diagnostics")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .onAppear {
                Task {
                    await authViewModel.fetchUser()
                }
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    Task { await authViewModel.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    Task { await authViewModel.deleteClerk() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
        }
    }
}
