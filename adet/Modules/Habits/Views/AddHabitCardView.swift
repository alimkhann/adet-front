import SwiftUI

struct AddHabitCardView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
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
}
