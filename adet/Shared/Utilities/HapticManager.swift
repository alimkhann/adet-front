import Foundation
import UIKit
import SwiftUI

class HapticManager {
    static let shared = HapticManager()

    @AppStorage("haptics") private var hapticsEnabled: Bool = true

    private init() {}

    func selection() {
        guard hapticsEnabled else { return }
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticsEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticsEnabled else { return }
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
