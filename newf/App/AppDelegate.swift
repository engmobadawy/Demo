import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UIWindow.installActivityTracking()

        let nc = NotificationCenter.default

        nc.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        nc.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        if application.applicationState != .active {
            PrivacyScreen.shared.show()
        }

        return true
    }

    // MARK: - Privacy Blur

    @objc private func appWillResignActive() {
        PrivacyScreen.shared.show()
    }

    @objc private func appDidBecomeActive() {
        PrivacyScreen.shared.hide()
    }

    // MARK: - Session Lock

    @objc private func appDidEnterBackground() {
        Task { @MainActor in
            SessionLockManager.shared.appDidEnterBackground()
        }
    }

    @objc private func appWillEnterForeground() {
        Task { @MainActor in
            SessionLockManager.shared.appWillEnterForeground()
        }
    }
}
