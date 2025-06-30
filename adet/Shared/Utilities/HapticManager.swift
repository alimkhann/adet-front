import UIKit
import SwiftUI

/// Manages haptic feedback throughout the app
class HapticManager {
    static let shared = HapticManager()

    private init() {}

    /// Light impact feedback - for subtle interactions
    func lightImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    /// Medium impact feedback - for standard interactions
    func mediumImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    /// Heavy impact feedback - for significant actions
    func heavyImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }

    /// Success notification feedback
    func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }

    /// Warning notification feedback
    func warning() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }

    /// Error notification feedback
    func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }

    /// Selection feedback - for picker/tab interactions
    func selection() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Adds haptic feedback to any view tap gesture
    func hapticFeedback(_ style: HapticStyle) -> some View {
        self.onTapGesture {
            switch style {
            case .light:
                HapticManager.shared.lightImpact()
            case .medium:
                HapticManager.shared.mediumImpact()
            case .heavy:
                HapticManager.shared.heavyImpact()
            case .success:
                HapticManager.shared.success()
            case .warning:
                HapticManager.shared.warning()
            case .error:
                HapticManager.shared.error()
            case .selection:
                HapticManager.shared.selection()
            }
        }
    }
}

// MARK: - Haptic Style Enum

enum HapticStyle {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
    case selection
}