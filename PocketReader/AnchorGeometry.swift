import Foundation

/// All coordinates are panel pixels relative to the usable reading lane.
/// Uses the measured ink center of the first eojeol, never an English ORP rule.
enum AnchorGeometry {
    struct Placement {
        let origin: Double
        let left: Double
        let right: Double
        let anchor: Double?
        func fits(in width: Double) -> Bool { left >= -0.001 && right <= width + 0.001 }
    }
    static func placement(width: Double, firstWidth: Double, firstCenter: Double? = nil, inkLeft: Double = 0, settings: ReaderSettings) -> Placement {
        let lane = ReadingEngine.usableWidth(settings)
        guard settings.alignment == .gazeAnchor else { return Placement(origin: max(0, -inkLeft), left: max(0, -inkLeft) + inkLeft, right: max(0, -inkLeft) + width, anchor: nil) }
        let anchor = lane * min(0.5, max(0.2, settings.anchorFraction))
        let left = anchor - (firstCenter ?? firstWidth / 2)
        return Placement(origin: left, left: left + inkLeft, right: left + width, anchor: anchor)
    }
    static func maximumUnitWidth(firstWidth: Double, settings: ReaderSettings) -> Double {
        guard settings.alignment == .gazeAnchor else { return ReadingEngine.usableWidth(settings) }
        let lane = ReadingEngine.usableWidth(settings)
        return lane * (1 - min(0.5, max(0.2, settings.anchorFraction))) + firstWidth / 2
    }

}

enum PresentationGeometry {
    static func currentTop(settings: ReaderSettings) -> Double {
        let height = settings.panel.pixels.height
        let line = Double(ReadingEngine.font(settings).lineHeight)
        if settings.presentation == .current { return max(0, (height - line) / 2) }
        let inset = min(settings.padding, max(0, height - 8 - line))
        return max(0, height - inset - 8 - line)
    }
}
