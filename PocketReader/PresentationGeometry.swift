import Foundation

enum PresentationGeometry {
    static func currentTop(settings: ReaderSettings) -> Double {
        let height = settings.panel.pixels.height
        let line = Double(ReadingEngine.font(settings).lineHeight)
        if settings.presentation == .current { return max(0, (height - line) / 2) }
        let inset = min(settings.padding, max(0, height - 8 - line))
        return max(0, height - inset - 8 - line)
    }
}
