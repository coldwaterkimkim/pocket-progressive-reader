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
            "lineGap": store.settings.lineGap * scale
        ]
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
        private var mountedPayload = ""
        private var lastFocus = ""
        private var lastCoarse: Int?

        init(store: ReaderStore) { self.store = store }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded = true
            synchronize()
        }

        func synchronize() {
            guard loaded, let webView,
                  let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
                  let json = String(data: data, encoding: .utf8) else { return }
            if json != mountedPayload {
                mountedPayload = json
                lastFocus = ""
                lastCoarse = nil
                webView.evaluateJavaScript("RichReader.mount(\(json));")
            }
            if let coarse, coarse != lastCoarse {
                webView.evaluateJavaScript("RichReader.ensureTokenVisible(\(coarse));")
            }
            lastCoarse = coarse
            let focusArgument = focus.map(String.init) ?? "null"
            let focusKey = focusArgument + style
            if focusKey != lastFocus {
                lastFocus = focusKey
                webView.evaluateJavaScript("RichReader.focus(\(focusArgument), '\(style)');")
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
