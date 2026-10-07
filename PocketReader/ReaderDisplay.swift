import SwiftUI
import UIKit
import CoreText

struct ReaderDisplay: View {
    let store: ReaderStore
    let width: Double

    private var scale: Double { width / store.settings.panel.pixels.width }
    private var height: Double { store.settings.panel.pixels.height * scale }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [Color(white: 0.52), Color(white: 0.88), Color(white: 0.52)], startPoint: .top, endPoint: .bottom))
                .padding(-6)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.16))
                .padding(-3)
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
            ZStack(alignment: .topLeading) {
                ReaderPalette.lcd
                LinearGradient(colors: [.black.opacity(0.025), .clear, .white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                displayText
                if store.settings.showProgress {
                    Capsule()
                        .fill(.black.opacity(0.13))
                        .frame(width: max(0, width - 2 * store.settings.padding * scale), height: 1.5)
                        .overlay(alignment: .leading) {
                            Capsule().fill(.black.opacity(0.5))
                                .frame(width: max(0, width - 2 * store.settings.padding * scale) * store.progress, height: 1.5)
                        }
                        .offset(x: store.settings.padding * scale, y: height - 5 * scale)
                        .accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.black.opacity(0.35), lineWidth: 1))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.black.opacity(0.16), lineWidth: 3)
                    .blur(radius: 2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: width, height: height)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader.display")
    }

    private var displayText: some View {
        let settings = store.settings
        let lineHeight = Double(ReadingEngine.font(settings).lineHeight)
        let currentTop = PresentationGeometry.currentTop(settings: settings)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(store.visiblePast.enumerated()), id: \.element.id) { offset, unit in
                let distance = store.visiblePast.count - offset
                let alpha = [0.48, 0.28, 0.16, 0.10, 0.08, 0.06][min(distance - 1, 5)]
                renderedLine(unit, alpha: alpha, focused: nil)
                    .offset(x: lineX(unit), y: currentTop - Double(distance) * (lineHeight + settings.lineGap))
                    .accessibilityHidden(true)
            }
            renderedLine(store.current, alpha: 1, focused: store.focusedToken)
                .offset(x: store.current.map(lineX) ?? settings.padding, y: currentTop)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(store.current?.text ?? "설정에서 읽을 글을 넣어줘")
                .accessibilityIdentifier("reader.current")
                .accessibilityValue("\(store.index + (store.units.isEmpty ? 0 : 1)) / \(store.units.count)")
        }
        // Lay out at the panel's actual pixel font size, then scale the entire layer.
        // Setting a smaller font instead changes SF optical metrics and invalidates chunk bounds.
        .frame(width: settings.panel.pixels.width, height: settings.panel.pixels.height, alignment: .topLeading)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func lineX(_ unit: ReadingUnit) -> Double {
        store.settings.padding + max(0, -unit.inkLeft)
    }

    private func renderedLine(_ unit: ReadingUnit?, alpha: Double, focused: ReadingToken?) -> some View {
        let font = UIFont.systemFont(ofSize: store.settings.fontSize * (unit?.fontScale ?? 1))
        let lineHeight = Double(ReadingEngine.font(store.settings).lineHeight)
        let text = unit?.text ?? "설정에서 읽을 글을 넣어줘"
        return Canvas { context, _ in
            context.withCGContext { graphics in
                let attributed = NSAttributedString(string: text, attributes: [
                    .font: font,
                    NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true
                ])
                let line = CTLineCreateWithAttributedString(attributed)
                let baseline = font.ascender + (lineHeight - font.lineHeight) / 2
                func draw(_ color: UIColor) {
                    graphics.saveGState()
                    graphics.translateBy(x: 0, y: baseline)
                    graphics.scaleBy(x: 1, y: -1)
                    graphics.textMatrix = .identity
                    graphics.textPosition = .zero
                    graphics.setFillColor(color.cgColor)
                    CTLineDraw(line, graphics)
                    graphics.restoreGState()
                }
                let ink = UIColor(white: 0.12, alpha: alpha)
                guard let focused else { draw(ink); return }
                let rect = CGRect(x: focused.x, y: 0, width: focused.width, height: lineHeight)
                let style = store.settings.wordFocusStyle
                if style == .yellow {
                    graphics.setFillColor(UIColor(red: 1, green: 0.84, blue: 0.2, alpha: 0.7).cgColor)
                    graphics.fill(rect)
                } else if style == .highContrast {
                    graphics.setFillColor(UIColor(white: 0.08, alpha: 1).cgColor)
                    graphics.fill(rect)
                }
                draw(style == .dimOthers ? UIColor(white: 0.12, alpha: 0.25) : ink)
                if style == .underline {
                    graphics.setFillColor(ink.cgColor)
                    graphics.fill(CGRect(x: rect.minX, y: baseline + 2, width: rect.width, height: 1.5))
                } else if style == .color || style == .dimOthers || style == .highContrast {
                    graphics.saveGState()
                    graphics.clip(to: rect)
                    let focusInk = style == .color ? UIColor(red: 0.04, green: 0.28, blue: 0.65, alpha: 1)
                        : (style == .highContrast ? UIColor.white : ink)
                    // Redraw the same shaped line through a token clip. Font metrics and glyph positions never change.
                    draw(focusInk)
                    graphics.restoreGState()
                }
            }
        }
        .frame(width: max(1, unit?.width ?? store.settings.panel.pixels.width - 2 * store.settings.padding), height: lineHeight)
    }
}
