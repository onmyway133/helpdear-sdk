#if canImport(UIKit)
import SwiftUI
import WebKit

/// A Helpdear page (feature requests, help center or changelog) to place anywhere in SwiftUI,
/// for example as a tab or a navigation destination.
public struct HelpdearView: View {
    private let page: HelpdearPage
    private let onClose: (() -> Void)?
    @StateObject private var controller: HelpdearWebController

    /// - Parameters:
    ///   - page: Which page to open.
    ///   - onClose: Shows a close button when set, for example to dismiss a sheet.
    public init(page: HelpdearPage = .feedback, onClose: (() -> Void)? = nil) {
        self.page = page
        self.onClose = onClose
        _controller = StateObject(wrappedValue: HelpdearWebController(page: page))
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            WebViewHost(webView: controller.webView)
                .ignoresSafeArea(edges: .bottom)
                .opacity(controller.state == .loaded ? 1 : 0)
            switch controller.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(message):
                FailureView(message: message, retry: controller.load)
            case .loaded:
                EmptyView()
            }
            if let onClose {
                CloseButton(action: onClose)
                    .padding(12)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear { controller.onClose = onClose }
    }
}

extension View {
    /// Presents a Helpdear page in a sheet with a close button.
    public func helpdearSheet(isPresented: Binding<Bool>, page: HelpdearPage = .feedback) -> some View {
        sheet(isPresented: isPresented) {
            HelpdearView(page: page) { isPresented.wrappedValue = false }
        }
    }
}

private struct WebViewHost: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

private struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(Text("Close"))
        } else {
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.regularMaterial, in: Circle())
            }
            .accessibilityLabel(Text("Close"))
        }
    }
}

private struct FailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 56, height: 56)
                .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text("Can't load this page")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if #available(iOS 26, *) {
                Button("Try Again", action: retry)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
            } else {
                Button("Try Again", action: retry)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
