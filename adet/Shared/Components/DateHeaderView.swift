import SwiftUI

struct DateHeaderView: View {
    let date: Date

    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)

            Text(formatDate(date))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                )

            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()

            // Show year only if it's not current year
            if calendar.component(.year, from: date) != calendar.component(.year, from: Date()) {
                formatter.dateStyle = .medium
            } else {
                formatter.dateFormat = "MMMM d"
            }

            return formatter.string(from: date)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        DateHeaderView(date: Date()) // Today
        DateHeaderView(date: Date().addingTimeInterval(-86400)) // Yesterday
        DateHeaderView(date: Date().addingTimeInterval(-86400 * 7)) // Week ago
        DateHeaderView(date: Date().addingTimeInterval(-86400 * 365)) // Year ago
    }
    .padding()
}