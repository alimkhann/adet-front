import SwiftUI

struct AddHabitCardView: View {
    var onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressing = false

    var scale: CGFloat { isPressing ? 0.97 : 1.0 }

    var body: some View {
        VStack {
            Image(systemName: "plus")
                .font(.largeTitle)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 150, height: 100)
        .background(colorScheme == .dark ? .blue : .white)
        .cornerRadius(10)
        .scaleEffect(scale)
        .animation(.easeInOut(duration: 0.2), value: scale)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.0, pressing: { pressing in
            self.isPressing = pressing
        }, perform: {})
    }
}
