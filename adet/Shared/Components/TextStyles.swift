import SwiftUI

extension View {
    func foregroundLinearGradient(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) -> some View {
        self.overlay(
            LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
        )
        .mask(self)
    }
}
