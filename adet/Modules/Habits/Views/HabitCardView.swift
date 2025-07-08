import SwiftUI

struct HabitCardView: View {
    let habit: Habit
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let width: CGFloat?
    let height: CGFloat?
    let minHeight: CGFloat?
    let isTaskInProgress: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressing = false

    var scale: CGFloat { isPressing ? 0.97 : 1.0 }
    var baseLineWidth: CGFloat { isSelected ? 3 : 0 }
    var lineWidth: CGFloat { baseLineWidth * scale }

    init(habit: Habit,
         isSelected: Bool,
         onTap: @escaping () -> Void,
         onLongPress: @escaping () -> Void,
         width: CGFloat? = nil,
         height: CGFloat? = nil,
         minHeight: CGFloat? = nil,
         isTaskInProgress: Bool = false) {
        self.habit = habit
        self.isSelected = isSelected
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.width = width
        self.height = height
        self.minHeight = minHeight
        self.isTaskInProgress = isTaskInProgress
    }

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
        .frame(
            width: width,
            height: height,
            alignment: .center
        )
        .frame(
            maxWidth: width == nil ? .infinity : width,
            minHeight: minHeight,
            alignment: .leading
        )
        .background(colorScheme == .dark ? .black : .white)
        .cornerRadius(10)
        .scaleEffect(scale)
        .animation(.easeInOut(duration: 0.2), value: scale)
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
                .animation(.easeInOut(duration: 0.2), value: scale)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
        )
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            self.isPressing = pressing
        }, perform: {
            if !isTaskInProgress {
                onLongPress()
            }
        })
    }
}


