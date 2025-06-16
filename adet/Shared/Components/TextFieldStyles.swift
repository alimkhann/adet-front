import SwiftUI

struct StyledTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(colorScheme == .dark ? .zinc900 : .zinc100)
        .cornerRadius(10)
        .foregroundColor(colorScheme == .dark ? .white : .black)
        .autocapitalization(.none)
        .disableAutocorrection(true)
    }
}
