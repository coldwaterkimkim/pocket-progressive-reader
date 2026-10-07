import CoreText
import UIKit

/// Advance and ink bounds keep a line inside the lane. Token offsets share the same shaped line.
enum NativeTextMetrics {
    struct Measurement {
        let width: Double
        let inkLeft: Double
    }
    static func measure(_ text: String, font: UIFont) -> Measurement {
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attributed)
        let advance = CTLineGetTypographicBounds(line, nil, nil, nil)
        let ink = CTLineGetImageBounds(line, nil)
        let valid = !ink.isNull && !ink.isInfinite && ink.width > 0
        return Measurement(width: max(advance, valid ? ink.maxX : advance),
                           inkLeft: valid ? ink.minX : 0)
    }
    static func tokenPositions(text: String, ranges: [NSRange], font: UIFont) -> [(x: Double, width: Double)] {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
        return ranges.map { range in
            let start = CTLineGetOffsetForStringIndex(line, range.location, nil)
            let end = CTLineGetOffsetForStringIndex(line, NSMaxRange(range), nil)
            return (Double(min(start, end)), Double(abs(end - start)))
        }
    }

}
