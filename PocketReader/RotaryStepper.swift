import Foundation

/// Each real detent is counted immediately. Opposite residual never cancels a direction reversal.
struct RotaryStepper {
    private var lastAngle: Double?
    private var residual = 0.0
    mutating func reset() { lastAngle = nil; residual = 0 }
    mutating func consume(angle: Double, startAngle: Double) -> Int {
        let previous = lastAngle ?? startAngle
        lastAngle = angle
        var delta = angle - previous
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        if delta * residual < 0 { residual = 0 }
        residual += delta
        let detent = Double.pi / 12
        let steps = Int((residual / detent).rounded(.towardZero))
        residual -= Double(steps) * detent
        return steps
    }
}
