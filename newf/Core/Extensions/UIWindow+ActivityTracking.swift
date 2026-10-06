import UIKit

extension UIWindow {
    private static var hasInstalledActivityTracking = false

    static func installActivityTracking() {
        guard !hasInstalledActivityTracking else { return }
        hasInstalledActivityTracking = true

        let original = #selector(UIWindow.sendEvent(_:))
        let swizzled = #selector(UIWindow.swizzled_sendEvent(_:))
        guard let originalMethod = class_getInstanceMethod(UIWindow.self, original),
              let swizzledMethod = class_getInstanceMethod(UIWindow.self, swizzled) else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc private func swizzled_sendEvent(_ event: UIEvent) {
        swizzled_sendEvent(event)

        if event.type == .touches, let touches = event.allTouches, !touches.isEmpty {
            Task { @MainActor in
                SessionLockManager.shared.recordActivity()
            }
        }
    }
}
