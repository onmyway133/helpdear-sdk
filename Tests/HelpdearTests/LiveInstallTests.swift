#if canImport(WebKit)
import Foundation
import Testing
import WebKit
@testable import Helpdear

// Loads the embed page from a real Helpdear install in the SDK's WebView. Runs only when an
// install is given, for example a local `npm run dev`:
//
//   HELPDEAR_TEST_HOST=http://localhost:5173 HELPDEAR_TEST_KEY=w_... swift test
//
// It runs on the Mac (same WebKit and bridge as iOS); an iOS test process has no app to host a
// WebView.

private let environment = ProcessInfo.processInfo.environment
private let liveHost = environment["HELPDEAR_TEST_HOST"].flatMap(URL.init(string:))
private let liveKey = environment["HELPDEAR_TEST_KEY"]

@MainActor
@Suite(.enabled(if: liveHost != nil && liveKey != nil, "Set HELPDEAR_TEST_HOST and HELPDEAR_TEST_KEY"))
struct LiveInstallTests {
    @Test func startsAVisitorAndKeepsItsToken() async throws {
        let store = MemoryTokenStore()
        Helpdear.tokenStore = store
        Helpdear.configure(clientKey: try #require(liveKey), host: try #require(liveHost))
        Helpdear.setUser(id: "sdk-test-user", name: "SDK Test")
        let key = try #require(Helpdear.configuration).storageKey

        let first = HelpdearWebController(page: .feedback)
        first.webView.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let found = await waitForToken(store, key: key)
        let title = try? await first.webView.evaluateJavaScript("document.title + ' | ' + location.href + ' | ' + document.body.innerText.slice(0, 200)")
        let token = try #require(found, "state: \(first.state), page: \(String(describing: title))")
        #expect(token.hasPrefix("hdv_"))
        #expect(first.state == .loaded)

        // Opening the page again reuses the same visitor.
        let second = HelpdearWebController(page: .help)
        try await Task.sleep(for: .seconds(4))
        #expect(store.token(for: key) == token)
        _ = second

        Helpdear.reset()
        #expect(store.token(for: key) == nil)
    }

    private func waitForToken(_ store: MemoryTokenStore, key: String) async -> String? {
        for _ in 0..<60 {
            if let token = store.token(for: key) {
                return token
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return nil
    }
}
#endif
