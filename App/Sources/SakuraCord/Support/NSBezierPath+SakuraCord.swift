import AppKit
import SwiftUI

extension NSBezierPath {
    convenience init(
        concentricRoundedRect rect: CGRect,
        cornerRadius: CGFloat
    ) {
        #if compiler(>=6.4)
        let path = ConcentricRectangle(
            corners: .fixed(cornerRadius),
            isUniform: true
        )
        .path(in: rect)
        self.init(cgPath: path.cgPath)
        #else
        // On macOS 26, ConcentricRectangle outside a SwiftUI container ignores
        // the fixed radius and returns a plain rectangle, so avatars drew square.
        let radius = min(cornerRadius, rect.width / 2, rect.height / 2)
        self.init(roundedRect: rect, xRadius: radius, yRadius: radius)
        #endif
    }
}
