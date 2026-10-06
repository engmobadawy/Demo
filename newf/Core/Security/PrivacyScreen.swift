import UIKit

final class PrivacyScreen {
    static let shared = PrivacyScreen()

    private var blurViews: [UIWindow: UIVisualEffectView] = [:]
    private let lock = NSLock()

    private init() {}

    func show() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }

            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for window in windowScene.windows where !window.isHidden {
                    self.addBlur(to: window)
                }
            }
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }

            for (_, view) in self.blurViews {
                view.removeFromSuperview()
            }
            self.blurViews.removeAll()
        }
    }

    private func addBlur(to window: UIWindow) {
        guard blurViews[window] == nil else { return }

        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        blurView.frame = window.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.tag = 999_999_999

        let lockImageView = UIImageView(image: UIImage(systemName: "lock.fill"))
        lockImageView.tintColor = .secondaryLabel
        lockImageView.contentMode = .scaleAspectFit
        lockImageView.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(lockImageView)
        NSLayoutConstraint.activate([
            lockImageView.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            lockImageView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            lockImageView.widthAnchor.constraint(equalToConstant: 44),
            lockImageView.heightAnchor.constraint(equalToConstant: 44)
        ])

        window.addSubview(blurView)
        blurViews[window] = blurView
    }
}
