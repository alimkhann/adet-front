import SwiftUI

struct HabitCardView: View {
    let habit: Habit
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(habit.name)
                .font(.headline)
                .foregroundColor(.primary)

            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(habit.streak)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 150, height: 100)
        .background(colorScheme == .dark ? Color("Zinc900") : Color("Zinc100"))
        .cornerRadius(10)
        .scaleEffect(isPressing ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isPressing)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            self.isPressing = pressing
        }, perform: {
            onLongPress()
        })
    }
}
