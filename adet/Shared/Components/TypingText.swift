import SwiftUI

struct TypingText: View {
    let text: String
    var animatedDots: Bool = false
    var typingSpeed: Double = 0.04 // seconds per character
    var dotCount: Int = 3
    var dotSpeed: Double = 0.4

    @State private var displayedText: String = ""
    @State private var currentIndex: Int = 0
    @State private var dotPhase: Int = 0
    @State private var isTypingDone: Bool = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(displayedText)
                .animation(.none, value: displayedText)
            if animatedDots && isTypingDone {
                Text(String(repeating: ".", count: dotPhase + 1))
                    .animation(.easeInOut, value: dotPhase)
            }
        }
        .onAppear {
            displayedText = ""
            currentIndex = 0
            isTypingDone = false
            dotPhase = 0
            typeNextChar()
        }
    }

    private func typeNextChar() {
        guard currentIndex < text.count else {
            isTypingDone = true
            if animatedDots {
                animateDots()
            }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + typingSpeed) {
            let safeIndex = text.index(text.startIndex, offsetBy: min(currentIndex, text.count))
            let substring = text[..<safeIndex]
            displayedText = String(text[..<safeIndex])
            currentIndex += 1
            typeNextChar()
        }
    }

    private func animateDots() {
        DispatchQueue.main.asyncAfter(deadline: .now() + dotSpeed) {
            dotPhase = (dotPhase + 1) % dotCount
            animateDots()
        }
    }
}