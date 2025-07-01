import SwiftUI
import UIKit

class SharingHelper: ObservableObject {

    static let shared = SharingHelper()

    private init() {}

    func sharePost(_ post: Post, from sourceView: UIView? = nil) {
        let shareText = generateShareText(for: post)
        var activityItems: [Any] = [shareText]

        // Add the main media URL if it's an image
        if post.proofType == .image, let imageUrlString = post.proofUrls.first,
           let imageUrl = URL(string: imageUrlString) {
            activityItems.append(imageUrl)
        }

        presentActivityViewController(with: activityItems, from: sourceView)
    }

    func shareHabitStreak(habitName: String, streak: Int, from sourceView: UIView? = nil) {
        let shareText = generateStreakShareText(habitName: habitName, streak: streak)
        presentActivityViewController(with: [shareText], from: sourceView)
    }

    private func generateShareText(for post: Post) -> String {
        var text = ""

        // Add user context
        let userName = post.user.displayName
        text += "Check out \(userName)'s progress on Adet! 🎯\n\n"

        // Add description if available
        if let description = post.description, !description.isEmpty {
            text += "\"\(description)\"\n\n"
        }

        // Add habit streak info
        if let streak = post.habitStreak, streak > 0 {
            text += "🔥 \(streak) day streak!\n\n"
        }

        // Add app promotion
        text += "Join me on Adet - the AI-powered habit tracker that helps you stay motivated! 💪"

        return text
    }

    private func generateStreakShareText(habitName: String, streak: Int) -> String {
        var text = "🔥 Just hit a \(streak) day streak"

        if streak >= 100 {
            text += " - that's over 3 months"
        } else if streak >= 30 {
            text += " - that's a full month"
        } else if streak >= 7 {
            text += " - that's a full week"
        }

        text += " on my \(habitName) habit! 🎯\n\n"
        text += "Building lasting habits with Adet - the AI habit tracker that keeps me motivated every day! 💪"

        return text
    }

    private func presentActivityViewController(with items: [Any], from sourceView: UIView?) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else { return }

            let activityViewController = UIActivityViewController(
                activityItems: items,
                applicationActivities: nil
            )

            // Exclude some activities that don't make sense for habit sharing
            activityViewController.excludedActivityTypes = [
                .assignToContact,
                .addToReadingList,
                .openInIBooks
            ]

            // Configure for iPad
            if let popover = activityViewController.popoverPresentationController {
                if let sourceView = sourceView {
                    popover.sourceView = sourceView
                    popover.sourceRect = sourceView.bounds
                } else {
                    popover.sourceView = rootViewController.view
                    popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX,
                                              y: rootViewController.view.bounds.midY,
                                              width: 0,
                                              height: 0)
                }
                popover.permittedArrowDirections = []
            }

            rootViewController.present(activityViewController, animated: true)
        }
    }
}

// MARK: - SwiftUI Integration

struct ShareButton: UIViewRepresentable {
    let post: Post
    let onShare: () -> Void

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        button.addTarget(context.coordinator, action: #selector(Coordinator.sharePost), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {
        // Update if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        let parent: ShareButton

        init(_ parent: ShareButton) {
            self.parent = parent
        }

        @objc func sharePost() {
            parent.onShare()
            SharingHelper.shared.sharePost(parent.post)
        }
    }
}

// MARK: - Extensions

extension PostActionsView {
    func handleShare(for post: Post) {
        SharingHelper.shared.sharePost(post)
    }
}