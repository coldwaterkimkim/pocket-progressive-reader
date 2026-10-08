import SwiftUI
import UIKit

struct ClickWheel: View {
    let store: ReaderStore
    @State private var rotary = RotaryStepper()
    @State private var lastAngle: Double?
    @State private var scrubbing = false

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size.width
            ZStack {
                Circle()
                    .fill(.black.opacity(0.2))
                    .padding(-2)
                    .blur(radius: 1)
                    .offset(y: 1)
                IvorySurface()
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.95), .black.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 2)
                    .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1).padding(2))
                Circle()
                    .fill(.black.opacity(0.24))
                    .frame(width: size * 0.405, height: size * 0.405)
                    .blur(radius: 1)
                IvorySurface()
                    .clipShape(Circle())
                    .frame(width: size * 0.39, height: size * 0.39)
                    .overlay(Circle().strokeBorder(LinearGradient(colors: [.white, .black.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.16), radius: 2, y: 2)
                    .accessibilityHidden(true)
                wheelButton("triangle.fill", rotation: 0, label: "이전 문장", id: "wheel.up", x: size / 2, y: size * 0.11) { store.moveSentence(-1) }
                wheelButton("triangle.fill", rotation: 180, label: "다음 문장", id: "wheel.down", x: size / 2, y: size * 0.89) { store.moveSentence(1) }
                wheelButton("triangle.fill", rotation: -90, label: "이전 조각", id: "wheel.left", x: size * 0.11, y: size / 2) { store.move(-1) }
                wheelButton("triangle.fill", rotation: 90, label: "다음 조각", id: "wheel.right", x: size * 0.89, y: size / 2) { store.move(1) }
            }
            .contentShape(Circle())
            .simultaneousGesture(DragGesture(minimumDistance: 10)
                .onChanged { value in
                    let dx = value.location.x - size / 2
                    let dy = value.location.y - size / 2
                    let radius = hypot(dx, dy)
                    guard radius > size * 0.24, radius < size * 0.55 else {
                        lastAngle = nil
                        rotary.reset()
                        return
                    }
                    let started = scrubbing
                    scrubbing = true
                    let angle = atan2(dy, dx)
                    let startDX = value.startLocation.x - size / 2
                    let startDY = value.startLocation.y - size / 2
                    let startRadius = hypot(startDX, startDY)
                    let start = started && lastAngle == nil ? angle
                        : (startRadius > size * 0.24 && startRadius < size * 0.55 ? atan2(startDY, startDX) : angle)
                    let steps = rotary.consume(angle: angle, startAngle: start)
                    if steps != 0 { perform { store.moveFocus(steps) } }
                    lastAngle = angle
                }
                .onEnded { _ in
                    lastAngle = nil
                    rotary.reset()
                    // Keep release from becoming an accidental directional tap.
                    DispatchQueue.main.async { scrubbing = false }
                })
            .accessibilityElement(children: .contain)
            .accessibilityLabel("방향 클릭휠")
            .accessibilityIdentifier("wheel")
            .accessibilityValue(store.focusedToken?.text ?? "어절 포커스 없음")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: perform { store.moveFocus(1) }
                case .decrement: perform { store.moveFocus(-1) }
                @unknown default: break
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func wheelButton(_ symbol: String, rotation: Double, label: String, id: String, x: Double, y: Double, action: @escaping () -> Void) -> some View {
        Button {
            guard !scrubbing else { return }
            perform(action)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .regular))
                .rotationEffect(.degrees(rotation))
                .foregroundStyle(Color(white: 0.43))
                .shadow(color: .white.opacity(0.8), radius: 0, y: 1)
                .frame(width: 54, height: 54)
                .contentShape(Rectangle())
        }
        .buttonStyle(WheelPressStyle())
        .position(x: x, y: y)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private func perform(_ action: () -> Void) {
        let before = (store.index, store.focusedTokenIndex)
        action()
        if (before.0 != store.index || before.1 != store.focusedTokenIndex) && store.settings.haptics {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

private struct WheelPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
    }
}
