import Foundation
import Testing
@testable import Helpdear

@Suite struct ConfigurationTests {
    @Test func buildsTheEmbedURL() throws {
        let configuration = Configuration(clientKey: "w_abc", host: try #require(URL(string: "https://help.example.com/")))
        let url = try #require(configuration.embedURL(page: .changelog))
        #expect(url.absoluteString == "https://help.example.com/widget.html?embed=1&key=w_abc&view=changelog")
    }

    @Test func keepsAHostPath() throws {
        let configuration = Configuration(clientKey: "w_abc", host: try #require(URL(string: "http://localhost:5173/support")))
        let url = try #require(configuration.embedURL(page: .feedback))
        #expect(url.absoluteString == "http://localhost:5173/support/widget.html?embed=1&key=w_abc&view=feedback")
    }

    @Test func knowsWhichLinksStayInside() throws {
        let configuration = Configuration(clientKey: "w_abc", host: try #require(URL(string: "https://help.example.com")))
        #expect(configuration.isInstall(try #require(URL(string: "https://help.example.com/help/billing"))))
        #expect(!configuration.isInstall(try #require(URL(string: "https://helpdear.com/?ref=widget"))))
        #expect(!configuration.isInstall(try #require(URL(string: "http://help.example.com/"))))
    }

    @Test func storesTokensPerInstallAndApp() throws {
        let a = Configuration(clientKey: "w_1", host: try #require(URL(string: "https://help.example.com/")))
        let b = Configuration(clientKey: "w_1", host: try #require(URL(string: "https://help.example.com")))
        let c = Configuration(clientKey: "w_2", host: try #require(URL(string: "https://help.example.com")))
        #expect(a.storageKey == b.storageKey)
        #expect(a.storageKey != c.storageKey)
    }
}

@Suite struct BridgeTests {
    @Test func readsPageMessages() throws {
        #expect(PageMessage(body: ["type": "ready"]) == .ready)
        #expect(PageMessage(body: ["type": "session", "token": "hdv_1", "visitor": ["id": "v"]]) == .session(token: "hdv_1"))
        #expect(PageMessage(body: ["type": "session"]) == nil)
        #expect(PageMessage(body: ["type": "link", "url": "https://helpdear.com"]) == .link(try #require(URL(string: "https://helpdear.com"))))
        #expect(PageMessage(body: ["type": "unread", "count": 0]) == .other("unread"))
        #expect(PageMessage(body: "nonsense") == nil)
    }

    @Test func sendsInitWithTokenAndUser() throws {
        let message = AppMessage.initialize(token: "hdv_1", user: HelpdearUser(id: "user-42", name: "Ada", email: nil, hash: nil))
        let json = message.json
        #expect(json["type"] as? String == "init")
        #expect(json["token"] as? String == "hdv_1")
        let identify = try #require(json["identify"] as? [String: Any])
        #expect(identify["userId"] as? String == "user-42")
        #expect(identify["name"] as? String == "Ada")
        #expect(identify["email"] == nil)
    }

    @Test func sendsNullsForAnAnonymousFirstVisit() {
        let json = AppMessage.initialize(token: nil, user: nil).json
        #expect(json["token"] is NSNull)
        #expect(json["identify"] is NSNull)
    }

    @Test func escapesScriptLineSeparators() throws {
        let script = try #require(AppMessage.identify(HelpdearUser(id: "a\u{2028}b")).script)
        #expect(script.hasPrefix("window.__helpdearReceive && window.__helpdearReceive({"))
        #expect(!script.contains("\u{2028}"))
        #expect(script.contains("\\u2028"))
    }
}

@Suite struct TokenStoreTests {
    @Test func savesReplacesAndRemoves() {
        let store = MemoryTokenStore()
        store.save("one", for: "k")
        store.save("two", for: "k")
        #expect(store.token(for: "k") == "two")
        store.remove(for: "k")
        #expect(store.token(for: "k") == nil)
    }

    @MainActor @Test func resetForgetsTheVisitorAndUser() throws {
        let store = MemoryTokenStore()
        Helpdear.tokenStore = store
        Helpdear.configure(clientKey: "w_1", host: try #require(URL(string: "https://help.example.com")))
        let key = try #require(Helpdear.configuration).storageKey
        store.save("hdv_1", for: key)
        Helpdear.setUser(id: "user-42")
        #expect(Helpdear.user?.id == "user-42")
        Helpdear.reset()
        #expect(store.token(for: key) == nil)
        #expect(Helpdear.user == nil)
        Helpdear.setUser(id: nil)
        #expect(Helpdear.user == nil)
    }
}
