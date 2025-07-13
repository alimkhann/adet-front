import SwiftUI

struct AddHabitCardView: View {
    var onTap: () -> Void
    var isLocked: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressing = false

    var scale: CGFloat { isPressing ? 0.97 : 1.0 }

    var body: some View {
        VStack {
            Image(systemName: isLocked ? "lock.fill" : "plus")
                .font(.largeTitle)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 150, height: 100)
        .background(colorScheme == .dark ? .black : .white)
        .cornerRadius(10)
        .scaleEffect(scale)
        .animation(.easeInOut(duration: 0.2), value: scale)
        .opacity(isLocked ? 0.5 : 1.0)
        .onTapGesture {
            if !isLocked {
                onTap()
            }
        }
        .onLongPressGesture(minimumDuration: 0.0, pressing: { pressing in
            self.isPressing = pressing
        }, perform: {})
    }
}
