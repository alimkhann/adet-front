import SwiftUI
import Clerk

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(Clerk.self) private var clerk
    @State private var isEditingUsername = false
    @State private var newUsername = ""
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    // Debug section to show authentication state
//                    Section {
//                        Text("Auth Status: \(clerk.user != nil ? "Signed In" : "Not Signed In")")
//                        if let clerkUser = clerk.user {
//                            Text("Clerk User ID: \(clerkUser.id)")
//                        }
//                        Button("Refresh User") {
//                            authViewModel.fetchUser()
//                        }
//                    } header: {
//                        Text("Debug Info")
//                    }

                    if let user = authViewModel.user {
                        Section {
                            VStack(alignment: .leading, spacing: 4) {
                                if isEditingUsername {
                                    HStack {
                                        TextField("Username", text: $newUsername)
                                            .textFieldStyle(.roundedBorder)
                                        Button("Save") {
                                            Task {
                                                await authViewModel.updateUsername(newUsername)
                                                isEditingUsername = false
                                            }
                                        }
                                        .disabled(newUsername.isEmpty)
                                    }
                                } else {
                                    HStack {
                                        Text(user.username ?? "No username")
                                            .font(.headline)
                                        Spacer()
                                        Button("Edit") {
                                            newUsername = user.username ?? ""
                                            isEditingUsername = true
                                        }
                                    }
                                }

                                if let email = user.primaryEmailAddress?.emailAddress {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("No email")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
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
                }
                .listStyle(.insetGrouped)

                LoadingButton(title: "Sign Out",
                              isLoading: false) {
                    Task { try? await clerk.signOut() }
                }
                .accessibilityIdentifier("SignOut")
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Text("Delete Account")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .alert("Delete Account", isPresented: $showDeleteAlert) {
                    Button("Delete", role: .destructive) {
                        Task { await authViewModel.deleteClerk() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to delete your account? This action cannot be undone.")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                authViewModel.fetchUser()
            }
        }
    }
}
