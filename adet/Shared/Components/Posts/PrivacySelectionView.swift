import SwiftUI

struct PrivacySelectionView: View {
    @Binding var selectedPrivacy: PostPrivacy
    let onSelectionChanged: (PostPrivacy) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ForEach(PostPrivacy.allCases, id: \.self) { privacy in
                    PrivacyOptionRow(
                        privacy: privacy,
                        isSelected: selectedPrivacy == privacy,
                        onTap: {
                            selectedPrivacy = privacy
                            onSelectionChanged(privacy)
                        }
                    )
                }
            }
        }
    }
}

struct PrivacyOptionRow: View {
    let privacy: PostPrivacy
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: privacy.icon)
                    .foregroundColor(Color(privacy.privacyColor))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(privacy.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(privacy.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CompactPrivacySelector: View {
    @Binding var selectedPrivacy: PostPrivacy
    let onSelectionChanged: (PostPrivacy) -> Void

    var body: some View {
        Menu {
            ForEach(PostPrivacy.allCases, id: \.self) { privacy in
                Button {
                    selectedPrivacy = privacy
                    onSelectionChanged(privacy)
                } label: {
                    Label(privacy.displayName, systemImage: privacy.icon)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selectedPrivacy.icon)
                    .foregroundColor(Color(selectedPrivacy.privacyColor))

                Text(selectedPrivacy.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PrivacySelectionView(
            selectedPrivacy: .constant(.friends),
            onSelectionChanged: { _ in }
        )

        CompactPrivacySelector(
            selectedPrivacy: .constant(.closeFriends),
            onSelectionChanged: { _ in }
        )
    }
    .padding()
}