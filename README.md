# Helpdear SDK

Show feature requests (with voting), your help center and your changelog inside your iOS app,
served by your own [Helpdear](https://github.com/onmyway133/helpdear) install.

- iOS 16 and later: Swift package in this repo.
- Android: planned.

## Install

In Xcode, choose **File → Add Package Dependencies** and enter:

```
https://github.com/onmyway133/helpdear-sdk
```

Or in `Package.swift`:

```swift
.package(url: "https://github.com/onmyway133/helpdear-sdk", branch: "main")
```

## Configure

In your Helpdear dashboard, open **Settings → Websites and apps**, choose **Add a website or
app**, and pick iOS app. Copy the base URL and client key it shows, then call this once at launch:

```swift
import Helpdear

@main
struct MyApp: App {
    init() {
        Helpdear.configure(clientKey: "w_...", host: URL(string: "https://help.example.com")!)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Show a page

Three pages: `.feedback` (feature requests, voting and comments), `.help` (help center) and
`.changelog` (what's new). The page has tabs to move between them.

SwiftUI sheet with a close button:

```swift
struct SettingsView: View {
    @State private var showFeedback = false

    var body: some View {
        Button("Request a feature") { showFeedback = true }
            .helpdearSheet(isPresented: $showFeedback, page: .feedback)
    }
}
```

Anywhere in a SwiftUI hierarchy, for example a tab or a navigation destination:

```swift
HelpdearView(page: .help)
```

UIKit:

```swift
present(HelpdearViewController(page: .changelog), animated: true)
```

## Users

Without a user, each device is an anonymous visitor; it keeps its own votes and ideas.

If your app has accounts, pass an opaque user id (a UUID or a hash of your account id) so your
team sees who asked. Name and email are optional:

```swift
Helpdear.setUser(id: account.id, name: account.name, email: account.email)

// On sign out:
Helpdear.reset()
```

An unsigned user id is saved as a custom attribute on this device's visitor. It never links
devices or merges people. To keep one person's history across devices, sign the user id on your
server with the identity secret from **Settings → Websites and apps → Verified identities**
(HMAC-SHA256, hex) and pass it as `hash`:

```swift
Helpdear.setUser(id: account.id, name: account.name, hash: signatureFromYourServer)
```

## Privacy

The page is served by your own install, so nothing goes anywhere else. The SDK stores one
visitor token in the Keychain (this device only, not synced), and sends the user details you
pass. Links that leave your install open in Safari.

## Development

`swift test` runs the unit tests. To test against a running install (for example `npm run dev`
in the helpdear repo, with an iOS app added in its dashboard):

```sh
HELPDEAR_TEST_HOST=http://localhost:5173 HELPDEAR_TEST_KEY=w_... swift test
```

## License

MIT. See [LICENSE](LICENSE).
