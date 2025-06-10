import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack {
            Text("SettingsView")
                .padding(.bottom, 16)

            Button {
                authViewModel.signOut()
            } label: {
                Text("Sign Out")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
    }
}
