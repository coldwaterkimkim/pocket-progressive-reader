import SwiftUI
import UIKit

struct HomeView: View {
    @State private var store = ReaderStore(sample: ProcessInfo.processInfo.arguments.contains("--uitesting"))
    @State private var sheet: HomeSheet?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let maximumWidth = size.width * 0.895
            let desiredWidth = store.settings.panel.millimeters.width * store.settings.pointsPerMM
            let displayWidth = store.settings.actualSize ? min(maximumWidth, desiredWidth) : maximumWidth
            let displayHeight = displayWidth * store.settings.panel.pixels.height / store.settings.panel.pixels.width
            let wheelSize = min(size.width * 0.78, size.height * 0.39)
            let panelCenter = max(size.height * 0.25, displayHeight / 2 + geometry.safeAreaInsets.top + 16)
            let wheelCenter = max(size.height * 0.65, panelCenter + displayHeight / 2 + wheelSize / 2 + 38)
            ZStack {
                MetalSurface()
                ReaderDisplay(store: store, width: displayWidth)
                    .position(x: size.width / 2, y: panelCenter)
                ClickWheel(store: store)
                    .frame(width: wheelSize, height: wheelSize)
                    .position(x: size.width / 2, y: min(wheelCenter, size.height - geometry.safeAreaInsets.bottom - 75 - wheelSize / 2))
                Button { sheet = .settings } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(Color(white: 0.43))
                        .shadow(color: .white.opacity(0.9), radius: 0, y: 1)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("설정")
                .accessibilityIdentifier("home.settings")
                .position(x: size.width * 0.89, y: size.height - geometry.safeAreaInsets.bottom - 42)
                if store.settings.actualSize && desiredWidth > maximumWidth {
                    Text("화면 폭에 맞춰 축소됨")
                        .font(.caption2)
                        .foregroundStyle(.black.opacity(0.5))
                        .position(x: size.width / 2, y: panelCenter + displayHeight / 2 + 22)
                }
                if store.persistenceError != nil {
                    Text("저장 실패 · 설정에서 확인")
                        .font(.caption2)
                        .foregroundStyle(.black.opacity(0.65))
                        .position(x: size.width / 2, y: size.height - geometry.safeAreaInsets.bottom - 42)
                }
            }
            .transaction { $0.animation = nil }
        }
        .ignoresSafeArea()
        .sheet(item: $sheet) { _ in SettingsView(store: store) }
        .onChange(of: store.settings) { old, new in
            if old.segmentation != new.segmentation || old.panel != new.panel || old.fontSize != new.fontSize
                || old.padding != new.padding || old.presentation != new.presentation {
                store.rebuild()
            } else { store.refreshViewport(reset: old.scrollMarginLines != new.scrollMarginLines); store.save() }
        }
        .onChange(of: scenePhase) { _, phase in
            UIApplication.shared.isIdleTimerDisabled = phase == .active && sheet == nil
            if phase != .active { store.save() }
        }
        .onChange(of: sheet) { _, value in
            UIApplication.shared.isIdleTimerDisabled = value == nil && scenePhase == .active
            if value == nil { store.save() }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false; store.save() }
    }
}

private enum HomeSheet: String, Identifiable {
    case settings
    var id: String { rawValue }
}
