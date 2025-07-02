import SwiftUI

struct MessageInputView: View {
    @Binding var messageText: String
    let isSendingMessage: Bool
    let canSendMessage: Bool
    let onSendMessage: () -> Void
    let onTypingChanged: (Bool) -> Void

    // Edit mode support
    let isEditMode: Bool
    let onCancelEdit: (() -> Void)?

    init(
        messageText: Binding<String>,
        isSendingMessage: Bool,
        canSendMessage: Bool,
        onSendMessage: @escaping () -> Void,
        onTypingChanged: @escaping (Bool) -> Void,
        isEditMode: Bool = false,
        onCancelEdit: (() -> Void)? = nil
    ) {
        self._messageText = messageText
        self.isSendingMessage = isSendingMessage
        self.canSendMessage = canSendMessage
        self.onSendMessage = onSendMessage
        self.onTypingChanged = onTypingChanged
        self.isEditMode = isEditMode
        self.onCancelEdit = onCancelEdit
    }

    @FocusState private var isTextFieldFocused: Bool
    @State private var isTyping = false

    var body: some View {
        VStack(spacing: 0) {
            // Edit mode indicator
            if isEditMode {
                HStack {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.primary)

                    Text("Editing message")
                        .font(.caption)
                        .foregroundColor(.primary)

                    Spacer()

                    Button("Cancel") {
                        onCancelEdit?()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            }

            Divider()

            HStack(alignment: .bottom, spacing: 12) {
                // Message Text Field
                TextField(isEditMode ? "Edit message..." : "Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...6)
                    .focused($isTextFieldFocused)
                    .onChange(of: messageText) { oldValue, newValue in
                        handleTypingChange(oldValue: oldValue, newValue: newValue)
                    }
                    .onSubmit {
                        if canSendMessage {
                            onSendMessage()
                        }
                    }

                // Send/Save Button
                Button(action: onSendMessage) {
                    if isSendingMessage {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: isEditMode ? "checkmark" : "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 40, height: 40)
                .background(canSendMessage ? Color.accentColor : Color(.systemGray4))
                .cornerRadius(18)
                .disabled(!canSendMessage || isSendingMessage)
                .animation(.easeInOut(duration: 0.2), value: canSendMessage)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Helper Methods

    private func handleTypingChange(oldValue: String, newValue: String) {
        let wasEmpty = oldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isEmpty = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        // Send typing indicator when user starts typing
        if wasEmpty && !isEmpty && !isTyping {
            isTyping = true
            onTypingChanged(true)
        }
        // Stop typing indicator when user clears text
        else if !wasEmpty && isEmpty && isTyping {
            isTyping = false
            onTypingChanged(false)
        }
    }

    // Stop typing when view disappears
    func stopTyping() {
        if isTyping {
            isTyping = false
            onTypingChanged(false)
        }
    }
}

#Preview {
    VStack {
        Spacer()

        // Mock chat messages area
        VStack(spacing: 16) {
            Text("Chat messages would appear here...")
                .foregroundColor(.secondary)
                .padding()

            Spacer()
        }

        MessageInputView(
            messageText: .constant(""),
            isSendingMessage: false,
            canSendMessage: false,
            onSendMessage: { },
            onTypingChanged: { _ in }
        )
    }
    .background(Color(.systemGroupedBackground))
}
