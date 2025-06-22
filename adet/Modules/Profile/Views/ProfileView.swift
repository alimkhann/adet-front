import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.foreground)
                            .padding(8)
                    }
                }
                .padding(.top, 8)
                .padding(.trailing, 8)

                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 90, height: 90)
                        .foregroundStyle(.gray.opacity(0.3))
                        .background(Circle().fill(Color.white))
                        .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 2))
                        .shadow(radius: 2)

                    if let user = authViewModel.user {
                        VStack(spacing: 4) {
                            if let username = user.username {
                                Text(username)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                            } else {
                                Text("User")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                            }
                        }
                    } else {
                        Text("Loading...")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }
                }

                HStack(spacing: 24) {
                    StatCard(title: "Habits", value: "7", gradient: [Color.purple.opacity(0.08), Color.purple.opacity(0.16)])
                    StatCard(title: "Max Streak", value: "21", gradient: [Color.orange.opacity(0.08), Color.orange.opacity(0.16)])
                    StatCard(title: "Friends", value: "5", gradient: [Color.blue.opacity(0.08), Color.blue.opacity(0.16)])
                }
                .padding(.horizontal)

                Spacer()
            }
            .background(Color(.systemBackground))
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let gradient: [Color]

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 90, height: 80)
        .background(
            LinearGradient(gradient: Gradient(colors: gradient), startPoint: .top, endPoint: .bottom)
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 2)
    }
}
