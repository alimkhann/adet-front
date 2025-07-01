import Foundation
import UIKit

class HapticManager {
    static let shared = HapticManager()

    private init() {}

    func selection() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(type)
    }

    // Convenience methods
    func success() {
        notification(.success)
    }

    func error() {
        notification(.error)
    }

    func warning() {
        notification(.warning)
    }
}
