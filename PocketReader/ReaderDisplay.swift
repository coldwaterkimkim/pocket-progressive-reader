import SwiftUI
import UIKit

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
        let currentTop = (settings.panel.pixels.height - settings.padding - 8 - lineHeight) * scale
        return ZStack(alignment: .topLeading) {
            ForEach(Array(store.visiblePast.enumerated()), id: \.element.id) { offset, unit in
                let distance = store.visiblePast.count - offset
                let alpha = [0.48, 0.28, 0.16, 0.10, 0.08, 0.06][min(distance - 1, 5)]
                line(unit.text)
                    .foregroundStyle(ReaderPalette.ink.opacity(alpha))
                    .offset(x: settings.padding * scale, y: currentTop - Double(distance) * (lineHeight + settings.lineGap) * scale)
                    .accessibilityHidden(true)
            }
            line(store.current?.text ?? "설정에서 읽을 글을 넣어줘")
                .foregroundStyle(ReaderPalette.ink)
                .offset(x: settings.padding * scale, y: currentTop)
                .accessibilityIdentifier("reader.current")
                .accessibilityValue("\(store.index + (store.units.isEmpty ? 0 : 1)) / \(store.units.count)")
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .font(.system(size: store.settings.fontSize * scale))
            .lineLimit(1)
            .frame(width: max(1, width - store.settings.padding * scale * 2), height: Double(ReadingEngine.font(store.settings).lineHeight) * scale, alignment: .leading)
    }
}
