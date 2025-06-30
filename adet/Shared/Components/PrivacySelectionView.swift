import SwiftUI

struct PrivacySelectionView: View {
    @Binding var selectedPrivacy: PostPrivacy
    let onSelectionChanged: ((PostPrivacy) -> Void)?

    init(selectedPrivacy: Binding<PostPrivacy>, onSelectionChanged: ((PostPrivacy) -> Void)? = nil) {
        self._selectedPrivacy = selectedPrivacy
        self.onSelectionChanged = onSelectionChanged
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share with")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ForEach(PostPrivacy.allCases) { privacy in
                    PrivacyOptionRow(
                        privacy: privacy,
                        isSelected: selectedPrivacy == privacy,
                        onTap: {
                            selectedPrivacy = privacy
                            onSelectionChanged?(privacy)
                            HapticManager.shared.selectionFeedback()
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Privacy Option Row

struct PrivacyOptionRow: View {
    let privacy: PostPrivacy
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: privacy.icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)

                // Title and description
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

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20))
                        .foregroundColor(.gray.opacity(0.3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var iconColor: Color {
        switch privacy {
        case .private:
            return .orange
        case .friends:
            return .blue
        case .closeFriends:
            return .red
        }
    }
}

// MARK: - Compact Privacy Selector

struct CompactPrivacySelector: View {
    @Binding var selectedPrivacy: PostPrivacy
    let onSelectionChanged: ((PostPrivacy) -> Void)?

    init(selectedPrivacy: Binding<PostPrivacy>, onSelectionChanged: ((PostPrivacy) -> Void)? = nil) {
        self._selectedPrivacy = selectedPrivacy
        self.onSelectionChanged = onSelectionChanged
    }

    var body: some View {
        Menu {
            ForEach(PostPrivacy.allCases) { privacy in
                Button(action: {
                    selectedPrivacy = privacy
                    onSelectionChanged?(privacy)
                    HapticManager.shared.selectionFeedback()
                }) {
                    Label(privacy.displayName, systemImage: privacy.icon)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selectedPrivacy.icon)
                    .font(.system(size: 16))

                Text(selectedPrivacy.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
    }
}

#Preview("Full Privacy Selection") {
    VStack {
        PrivacySelectionView(selectedPrivacy: .constant(.friends))
        Spacer()
    }
    .padding()
}

#Preview("Compact Privacy Selector") {
    VStack {
        CompactPrivacySelector(selectedPrivacy: .constant(.closeFriends))
        Spacer()
    }
    .padding()
}