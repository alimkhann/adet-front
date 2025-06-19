import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
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
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
    }
}
