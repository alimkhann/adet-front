import SwiftUI

struct HabitCardView: View {
    let habit: Habit
    @Environment(\.colorScheme) private var colorScheme

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
    }
}
