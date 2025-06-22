import SwiftUI

struct AddHabitCardView: View {
    var onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressing = false

    var body: some View {
        Button(action: onTap) {
            VStack {
                Image(systemName: "plus")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(width: 150, height: 100)
            .background(colorScheme == .dark ? Color("Zinc900").opacity(0.5) : Color("Zinc100").opacity(0.8))
            .cornerRadius(10)
        }
        .scaleEffect(isPressing ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isPressing)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressing = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressing = false
                }
            }
            onTap()
        }
    }
}
