import SwiftUI

struct HabitCardView: View {
    let habit: Habit
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressing = false

    var scale: CGFloat { isPressing ? 0.95 : 1.0 }
    var baseLineWidth: CGFloat { isSelected ? 3 : 0 }
    var lineWidth: CGFloat { baseLineWidth * scale }

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
        .scaleEffect(scale)
        .animation(.easeInOut(duration: 0.2), value: isPressing)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isSelected
                        ? AnyShapeStyle(
                            LinearGradient(
                                stops: [
                                    .init(color: (colorScheme == .dark ? Color("Zinc400") : Color("Zinc700")), location: 0.0),
                                    .init(color: (colorScheme == .dark ? Color("Zinc400") : Color("Zinc700")), location: 0.75),
                                    .init(color: (colorScheme == .dark ? Color("Zinc900") : Color("Zinc100")).opacity(0.0), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(Color.clear),
                    lineWidth: lineWidth
                )
                .scaleEffect(scale)
                .animation(.easeInOut(duration: 0.2), value: isPressing)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
        )
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
