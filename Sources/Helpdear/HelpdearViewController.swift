#if canImport(UIKit)
import SwiftUI
import UIKit

/// A Helpdear page for UIKit apps. Presented modally, it shows a close button and dismisses itself.
///
/// ```swift
/// present(HelpdearViewController(page: .feedback), animated: true)
/// ```
public final class HelpdearViewController: UIHostingController<HelpdearView> {
    public init(page: HelpdearPage = .feedback) {
        // The close action needs self, which exists only after super.init.
        weak var weakSelf: HelpdearViewController?
        super.init(rootView: HelpdearView(page: page) { weakSelf?.dismiss(animated: true) })
        weakSelf = self
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
#endif
