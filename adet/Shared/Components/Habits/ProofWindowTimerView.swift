import SwiftUI

struct ProofWindowTimerView: View {
    public let validationTime: Date
    @State private var now: Date = Date()
    private var timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    public init(validationTime: Date) {
        self.validationTime = validationTime
    }

    private var timeLeft: TimeInterval {
        let windowEnd = validationTime.addingTimeInterval(4 * 3600)
        if now < validationTime {
            return validationTime.timeIntervalSince(now)
        } else if now >= validationTime && now <= windowEnd {
            return windowEnd.timeIntervalSince(now)
        } else {
            return 0
        }
    }

    private var hours: Int { Int(timeLeft) / 3600 }
    private var minutes: Int { (Int(timeLeft) % 3600) / 60 }

    var body: some View {
        HStack {
            Image(systemName: "clock")
            if timeLeft > 0 {
                if hours > 0 {
            Text(String(format: "%02dh %02dm left", hours, minutes))
                } else {
                    Text(String(format: "%02dm left", minutes))
                }
            } else {
                Text("Expired")
            }
        }
        .onReceive(timer) { _ in now = Date() }
        .onAppear { now = Date() }
    }
}
