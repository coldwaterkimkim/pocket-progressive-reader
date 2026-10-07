import CoreText
import UIKit

/// Advance width keeps all text inside the lane; ink bounds locate the visible first eojeol.
enum NativeTextMetrics {
    struct Measurement {
        let width: Double
        let inkLeft: Double
        let inkCenter: Double
    }
    static func measure(_ text: String, font: UIFont) -> Measurement {
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attributed)
        let advance = CTLineGetTypographicBounds(line, nil, nil, nil)
        let ink = CTLineGetImageBounds(line, nil)
        let valid = !ink.isNull && !ink.isInfinite && ink.width > 0
        return Measurement(width: max(advance, valid ? ink.maxX : advance),
                           inkLeft: valid ? ink.minX : 0,
                           inkCenter: valid ? ink.midX : advance / 2)
    }
}
