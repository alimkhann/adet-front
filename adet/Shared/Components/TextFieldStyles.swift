import SwiftUI

struct StyledTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

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
        .background(.zinc900)
        .cornerRadius(10)
        .foregroundColor(.white)
        .autocapitalization(.none)
        .disableAutocorrection(true)
    }
}
