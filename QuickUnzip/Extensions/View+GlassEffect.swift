import SwiftUI

extension View {
    @ViewBuilder
    func conditionalGlassEffect() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26, *) {
            self.glassEffect()
        } else {
            self
        }
        #else
        self
        #endif
    }
}
