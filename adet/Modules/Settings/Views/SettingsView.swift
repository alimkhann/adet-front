import SwiftUI
import Clerk

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(Clerk.self) private var clerk
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
                                Text(user.username ?? "No username")
                                    .font(.headline)
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
                .accessibilityIdentifier("Sign In")
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

                LoadingButton(title: "Delete Account",
                              isLoading: false) {
                    showDeleteAlert = true
                }
                .accessibilityIdentifier("Delete Account")
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .alert("Are you sure you want to delete your account? This action cannot be undone.", isPresented: $showDeleteAlert) {
                    Button("Delete", role: .destructive) {
                        Task { await authViewModel.deleteClerk() }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                authViewModel.fetchUser()
            }
        }
    }
}
