import Foundation

/// Shows a Helpdear install's feature requests, help center and changelog inside your app.
///
/// Call ``configure(clientKey:host:)`` once at launch, then present ``HelpdearView``,
/// `.helpdearSheet(isPresented:page:)` or `HelpdearViewController`.
@MainActor
public enum Helpdear {
    /// The package version, sent nowhere; handy in bug reports.
    public nonisolated static let version = "0.1.0"

    static var configuration: Configuration?
    static var user: HelpdearUser?
    static var tokenStore: TokenStore = KeychainTokenStore()

    /// Sets the install and the app. Every install is self-hosted, so there is no default host.
    ///
    /// - Parameters:
    ///   - clientKey: The app's client key from the Helpdear dashboard (Settings → Websites and apps).
    ///   - host: Your install's address, for example `https://help.example.com`.
    public static func configure(clientKey: String, host: URL) {
        configuration = Configuration(clientKey: clientKey, host: host)
    }

    /// Tells Helpdear who is using the app, so your team sees who asked for what.
    ///
    /// Pass an opaque user id (a UUID or a hash of your account id). Without a `hash` it's kept as
    /// a custom attribute on this device's visitor and never links devices or merges contacts.
    /// With `hash`, an HMAC-SHA256 of the user id made with the install's identity secret on your
    /// server, the same person keeps their history on every device.
    public static func setUser(id: String?, name: String? = nil, email: String? = nil, hash: String? = nil) {
        let next = HelpdearUser(id: id, name: name, email: email, hash: hash)
        user = next.isEmpty ? nil : next
        NotificationCenter.default.post(name: .helpdearUserChanged, object: nil)
    }

    /// Forgets the user and this device's visitor, for example on sign out.
    public static func reset() {
        if let configuration {
            tokenStore.remove(for: configuration.storageKey)
        }
        user = nil
        NotificationCenter.default.post(name: .helpdearReset, object: nil)
    }
}

/// The pages the SDK can open.
public enum HelpdearPage: String, Sendable, CaseIterable {
    /// Feature requests: post ideas, vote and comment.
    case feedback
    /// The help center: search and read articles.
    case help
    /// What's new.
    case changelog
}

/// The person using the app, as passed to ``Helpdear/setUser(id:name:email:hash:)``.
struct HelpdearUser: Equatable, Sendable {
    var id: String?
    var name: String?
    var email: String?
    var hash: String?

    var isEmpty: Bool {
        [id, name, email, hash].allSatisfy { ($0 ?? "").isEmpty }
    }
}

struct Configuration: Equatable, Sendable {
    var clientKey: String
    var host: URL

    /// The visitor token belongs to one install and one app.
    var storageKey: String {
        "\(host.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")))|\(clientKey)"
    }

    /// The install's embed page for the mobile SDK.
    func embedURL(page: HelpdearPage) -> URL? {
        guard var components = URLComponents(url: host, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let base = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = base + "/widget.html"
        components.queryItems = [
            URLQueryItem(name: "embed", value: "1"),
            URLQueryItem(name: "key", value: clientKey),
            URLQueryItem(name: "view", value: page.rawValue),
        ]
        return components.url
    }

    /// Whether a URL belongs to the install; anything else opens outside the app.
    func isInstall(_ url: URL) -> Bool {
        url.scheme == host.scheme && url.host == host.host && url.port == host.port
    }
}

extension Notification.Name {
    static let helpdearUserChanged = Notification.Name("HelpdearUserChanged")
    static let helpdearReset = Notification.Name("HelpdearReset")
}
