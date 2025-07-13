import SwiftUI

struct MotivationStepperView: View {
    let current: String?
    let onSet: (String) -> Void
    let onBack: () -> Void
    @State private var selected: String? = nil
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("How motivated are you?")
                .font(.headline)

            ForEach(["low", "medium", "high"], id: \.self) { level in
                let isSelected = (selected ?? current)?.lowercased() == level
                Button(action: { selected = level }) {
                    Text(level.capitalized)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? (isSelected ? Color.white : Color.black) : (isSelected ? Color.black : Color.white))
                        )
                        .foregroundColor(colorScheme == .dark ? (isSelected ? Color.black : Color.white) : (isSelected ? Color.white : Color.black))
                }
            }

            Spacer()

            HStack {
                Button {
                    if let c = selected ?? current {
                        onSet(c.lowercased())
                    }
                } label: {
                    Text("Set Motivation")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled((selected ?? current) == nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct AbilityStepperView: View {
    let current: String?
    let onSet: (String) -> Void
    let onBack: () -> Void
    @State private var selected: String? = nil
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("How able are you to do this?").font(.headline)

            ForEach(["hard", "medium", "easy"], id: \.self) { level in
                let isSelected = (selected ?? current)?.lowercased() == level
                Button(action: { selected = level }) {
                    Text(level.capitalized)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? (isSelected ? Color.white : Color.black) : (isSelected ? Color.black : Color.white))
                        )
                        .foregroundColor(colorScheme == .dark ? (isSelected ? Color.black : Color.white) : (isSelected ? Color.white : Color.black))
                }
            }

            Spacer()

            HStack {
                Button(action: onBack) {
                    Text("Back")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    if let c = selected ?? current {
                        onSet(c.lowercased())
                    }
                } label: {
                    Text("Set Ability")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled((selected ?? current) == nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
