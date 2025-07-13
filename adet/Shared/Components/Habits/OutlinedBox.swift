import SwiftUI

struct OutlinedBox<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) var colorScheme
    
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    
    var body: some View {
        HStack(alignment: .top) {
            content
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    colorScheme == .dark ?
                    AnyShapeStyle(Color.white.opacity(0.15)) :
                        AnyShapeStyle(Color.gray.opacity(0.2)), lineWidth: 1
                )
        )
    }
}
