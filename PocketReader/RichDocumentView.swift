import SwiftUI
import WebKit

/// Full and horizontal reading use one bundled, sanitized GFM renderer and its DOM token order.
struct RichDocumentView: UIViewRepresentable {
    let store: ReaderStore
    let width: Double
    let height: Double

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "reader")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.accessibilityIdentifier = "reader.document"
        context.coordinator.webView = webView
        updateConfiguration(context.coordinator)
        if let file = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "RichReader")
            ?? Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(file, allowingReadAccessTo: file.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.store = store
        updateConfiguration(context.coordinator)
        webView.accessibilityIdentifier = store.settings.presentation == .horizontal ? "reader.horizontal" : "reader.document"
        context.coordinator.synchronize()
    }

    private func updateConfiguration(_ coordinator: Coordinator) {
        let scale = width / store.settings.panel.pixels.width
        coordinator.payload = [
            "source": store.text,
            "format": store.sourceFormat.rawValue,
            "horizontal": store.settings.presentation == .horizontal,
            "fontSize": store.settings.fontSize * scale,
            "padding": store.settings.padding * scale,
            "lineGap": store.settings.lineGap * scale,
            "scrollMarginLines": store.settings.scrollMarginLines
        ]
        coordinator.renderKey = "\(store.sourceFormat.rawValue)|\(store.settings.presentation == .horizontal)|\(store.settings.fontSize * scale)|\(store.settings.padding * scale)|\(store.settings.lineGap * scale)|\(store.settings.scrollMarginLines)"
        coordinator.focus = store.globalFocusedTokenIndex
        coordinator.coarse = store.coarseTokenIndex
        coordinator.style = store.settings.wordFocusStyle.rawValue
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "reader")
        uiView.navigationDelegate = nil
        uiView.stopLoading()
    }

    @MainActor final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var store: ReaderStore
        weak var webView: WKWebView?
        var payload: [String: Any] = [:]
        var focus: Int?
        var coarse: Int?
        var style = "yellow"
        private var loaded = false
        var renderKey = ""
        private var mountedSource: String?
        private var mountedKey = ""
        private var lastVisualKey = ""
        private var inFlight = false

        init(store: ReaderStore) { self.store = store }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded = true
            synchronize()
        }

        func synchronize() {
            guard loaded, !inFlight, let webView else { return }
            // Source stays a Swift value and is serialized only when the document/layout changes.
            if mountedSource != store.text || mountedKey != renderKey {
                guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
                      let json = String(data: data, encoding: .utf8) else { return }
                mountedSource = store.text; mountedKey = renderKey; lastVisualKey = ""
                inFlight = true
                webView.evaluateJavaScript("RichReader.mount(\(json));") { [weak self] _, _ in
                    guard let self else { return }
                    self.inFlight = false; self.synchronize()
                }
                return
            }
            let selected = store.globalFocusedTokenIndex
            let coarse = store.coarseTokenIndex
            let style = store.settings.wordFocusStyle.rawValue
            let argument = selected.map(String.init) ?? "null"
            let key = "\(argument)|\(coarse.map(String.init) ?? "null")|\(style)"
            guard key != lastVisualKey else { return }
            lastVisualKey = key; inFlight = true
            let scroll = selected == nil ? coarse.map { "RichReader.ensureTokenVisible(\($0));" } ?? "" : ""
            // One visual request at a time; on completion use the latest Store cursor, never a stale queue.
            webView.evaluateJavaScript("RichReader.focus(\(argument), '\(style)');\(scroll)") { [weak self] _, _ in
                guard let self else { return }
                self.inFlight = false; self.synchronize()
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "reader", let body = message.body as? [String: Any], let text = body["text"] as? String else { return }
            // The original Markdown remains untouched; only the derived reading stream changes.
            store.acceptRenderedDocumentText(text)
            synchronize()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
            if navigationAction.navigationType == .linkActivated {
                if ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(url.isFileURL || url.scheme == "about" ? .allow : .cancel)
            }
        }
    }
}
