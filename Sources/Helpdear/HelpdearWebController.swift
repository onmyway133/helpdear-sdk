#if canImport(WebKit)
import WebKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Owns the WebView that shows the install's embed page, and speaks the bridge.
/// Shared by HelpdearView (SwiftUI) and HelpdearViewController (UIKit).
@MainActor
final class HelpdearWebController: NSObject, ObservableObject {
    enum State: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    let page: HelpdearPage
    let webView: WKWebView
    var onClose: (() -> Void)?
    private var configuration: Configuration?
    private var observers: [NSObjectProtocol] = []

    init(page: HelpdearPage) {
        self.page = page
        let settings = WKWebViewConfiguration()
        settings.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: settings)
        super.init()
        // The content controller keeps its handlers strongly; a weak proxy avoids a cycle.
        settings.userContentController.add(WeakMessageHandler(self), name: "helpdear")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        #if canImport(UIKit)
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        #endif
        observers = [
            NotificationCenter.default.addObserver(forName: .helpdearUserChanged, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.userChanged() }
            },
            NotificationCenter.default.addObserver(forName: .helpdearReset, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.send(.reset) }
            },
        ]
        load()
    }

    isolated deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "helpdear")
    }

    func load() {
        guard let configuration = Helpdear.configuration, let url = configuration.embedURL(page: page) else {
            state = .failed("Helpdear isn't configured. Call Helpdear.configure(clientKey:host:) at launch.")
            return
        }
        self.configuration = configuration
        state = .loading
        webView.load(URLRequest(url: url))
    }

    fileprivate func receive(_ body: Any) {
        guard let message = PageMessage(body: body), let configuration else {
            return
        }
        switch message {
        case .ready:
            let token = Helpdear.tokenStore.token(for: configuration.storageKey)
            send(.initialize(token: token, user: Helpdear.user))
        case let .session(token):
            Helpdear.tokenStore.save(token, for: configuration.storageKey)
            state = .loaded
        case .close:
            onClose?()
        case let .link(url):
            openOutside(url)
        case .other:
            break
        }
    }

    private func userChanged() {
        if let user = Helpdear.user {
            send(.identify(user))
        }
    }

    private func send(_ message: AppMessage) {
        guard let script = message.script else {
            return
        }
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func openOutside(_ url: URL) {
        guard ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") else {
            return
        }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }
}

extension HelpdearWebController: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url, let configuration else {
            return .cancel
        }
        if configuration.isInstall(url) || url.scheme == "about" {
            return .allow
        }
        // Links that leave the install open in the browser, not inside the app.
        openOutside(url)
        return .cancel
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // The page shows its own errors (an unknown client key, for example) once it has loaded.
        if state == .loading {
            state = .loaded
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        load()
    }

    // target=_blank links ask for a new window: open them outside instead.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            openOutside(url)
        }
        return nil
    }

    private func fail(_ error: Error) {
        if (error as NSError).code == NSURLErrorCancelled {
            return
        }
        state = .failed(error.localizedDescription)
    }
}

private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: HelpdearWebController?

    init(_ target: HelpdearWebController) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        MainActor.assumeIsolated {
            target?.receive(message.body)
        }
    }
}
#endif
