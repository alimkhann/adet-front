import SwiftUI

struct LargeRoundedTextView: View {
    let label: String
    
    var body: some View {
        Text(label)
            .font(.system(size: 36, weight: .heavy, design: .rounded))
            .overlay(
                LinearGradient(
                    colors: [Color.primary, Color.secondary],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .mask(
                Text(label)
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
            )
    }
}
