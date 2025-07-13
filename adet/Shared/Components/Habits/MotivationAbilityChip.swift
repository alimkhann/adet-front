import SwiftUI

struct MotivationAbilityChip: View {
    let value: String?
    let isMotivation: Bool
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        let isNotSet = (value == nil || value == "" || value?.lowercased() == "not set")
        let (background, stroke) = isNotSet ? (Color.gray.opacity(0.2), Color.gray.opacity(0.4)) : chipBackgroundAndStroke(for: value, isMotivation: isMotivation, colorScheme: colorScheme)
        let textColor = isNotSet ? Color.secondary : chipTextColor(for: value)
        HStack(spacing: 4) {
            Text(value ?? "Not set")
                .frame(maxWidth: .infinity)
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(background)
                .foregroundColor(textColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                )
        }
    }
}

// Returns (background, stroke) for set values, with theme-aware logic
private func chipBackgroundAndStroke(for value: String?, isMotivation: Bool, colorScheme: ColorScheme) -> (Color, Color) {
    guard let value = value?.lowercased() else {
        return (Color.gray.opacity(0.2), Color.gray.opacity(0.4))
    }
    let (dark, light): (Color, Color)
    switch isMotivation ? value : value {
    case "high", "easy":
        dark = Color.green.opacity(0.8)
        light = Color.green.opacity(0.7)
    case "medium":
        dark = Color.yellow.opacity(0.8)
        light = Color.yellow.opacity(0.7)
    case "low", "hard":
        dark = Color.red.opacity(0.8)
        light = Color.red.opacity(0.7)
    default:
        dark = Color.gray.opacity(0.2)
        light = Color.gray.opacity(0.4)
    }
    if colorScheme == .dark {
        // background dark, stroke light
        return (dark, light)
    } else {
        // background light, stroke dark
        return (light, dark)
    }
}

func chipColors(for value: String?, isMotivation: Bool) -> (Color, Color, Color) {
    guard let value = value?.lowercased() else {
        return (.gray.opacity(0.4), .gray.opacity(0.7), .black)
    }
    if isMotivation {
        switch value {
        case "high": return (.green.opacity(0.7), .green.opacity(0.8), Color(red:0.07, green:0.18, blue:0.07))
        case "medium": return (.yellow.opacity(0.7), .yellow.opacity(0.8), Color(red:0.18, green:0.18, blue:0.07))
        case "low": return (.red.opacity(0.7), .red.opacity(0.8), Color(red:0.18, green:0.07, blue:0.07))
        default: return (.gray.opacity(0.4), .gray.opacity(0.7), .black)
        }
    } else {
        switch value {
        case "easy": return (.green.opacity(0.7), .green.opacity(0.8), Color(red:0.07, green:0.18, blue:0.07))
        case "medium": return (.yellow.opacity(0.7), .yellow.opacity(0.8), Color(red:0.18, green:0.18, blue:0.07))
        case "hard": return (.red.opacity(0.7), .red.opacity(0.8), Color(red:0.18, green:0.07, blue:0.07))
        default: return (.gray.opacity(0.4), .gray.opacity(0.7), .black)
        }
    }
}

public func chipColor(for value: String?, isMotivation: Bool) -> Color {
    guard let value = value?.lowercased() else { return Color.gray.opacity(0.2) }
    if isMotivation {
        switch value {
        case "high": return .green
        case "medium": return .yellow
        case "low": return .red
        default: return Color.gray.opacity(0.2)
        }
    } else {
        switch value {
        case "easy": return .green
        case "medium": return .yellow
        case "hard": return .red
        default: return Color.gray.opacity(0.2)
        }
    }
}

public func chipTextColor(for value: String?) -> Color {
    guard let value = value?.lowercased() else { return .secondary }
    switch value {
    case "high", "easy": return .white
    case "medium": return .black
    case "low", "hard": return .white
    default: return .secondary
    }
}

