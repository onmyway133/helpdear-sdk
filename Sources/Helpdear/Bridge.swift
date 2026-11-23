import Foundation

// The messages between the install's embed page and the SDK. The page posts them to the
// `helpdear` script message handler; the SDK answers by calling `window.__helpdearReceive(...)`.
// The install documents this contract in src/widget/bridge.ts.

/// A message from the page.
enum PageMessage: Equatable {
    case ready
    case session(token: String)
    case close
    case link(URL)
    case other(String)

    init?(body: Any) {
        guard let dictionary = body as? [String: Any], let type = dictionary["type"] as? String else {
            return nil
        }
        switch type {
        case "ready":
            self = .ready
        case "session":
            guard let token = dictionary["token"] as? String, !token.isEmpty else {
                return nil
            }
            self = .session(token: token)
        case "close":
            self = .close
        case "link":
            guard let string = dictionary["url"] as? String, let url = URL(string: string) else {
                return nil
            }
            self = .link(url)
        default:
            self = .other(type)
        }
    }
}

/// A message to the page.
enum AppMessage {
    case initialize(token: String?, user: HelpdearUser?)
    case identify(HelpdearUser)
    case reset
    case open(HelpdearPage)

    var json: [String: Any] {
        switch self {
        case let .initialize(token, user):
            return [
                "type": "init",
                // The page takes the client key from its URL; this is only for the shape.
                "widgetId": "",
                "token": token ?? NSNull(),
                "page": ["url": "", "title": "", "referrer": ""],
                "identify": user.map(Self.identifyPayload) ?? NSNull(),
                "data": NSNull(),
            ]
        case let .identify(user):
            return ["type": "identify", "identify": Self.identifyPayload(user)]
        case .reset:
            return ["type": "reset"]
        case let .open(page):
            return ["type": "open", "view": page.rawValue]
        }
    }

    /// JavaScript that delivers the message, or nil if it can't be encoded.
    var script: String? {
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]),
              var literal = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        // JSON is valid JavaScript except for these two line separators.
        literal = literal
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        return "window.__helpdearReceive && window.__helpdearReceive(\(literal));"
    }

    private static func identifyPayload(_ user: HelpdearUser) -> [String: Any] {
        var result: [String: Any] = [:]
        if let id = user.id, !id.isEmpty { result["userId"] = id }
        if let name = user.name, !name.isEmpty { result["name"] = name }
        if let email = user.email, !email.isEmpty { result["email"] = email }
        if let hash = user.hash, !hash.isEmpty { result["hash"] = hash }
        return result
    }
}
