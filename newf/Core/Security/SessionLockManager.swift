import Foundation
import Combine

@MainActor
final class SessionLockManager: ObservableObject {
    static let shared = SessionLockManager()

    @Published private(set) var isLocked: Bool = false

    var foregroundTimeout: TimeInterval = 60
    var backgroundTimeout: TimeInterval = 30

    private var lastActivity: Date = Date()
    private var backgroundedAt: Date?
    private var timer: Timer?

    private init() {}

    func recordActivity() {
        let now = Date()
        if now.timeIntervalSince(lastActivity) < 0.5 { return }
        lastActivity = now
    }

    func appDidEnterBackground() {
        backgroundedAt = Date()
        stopTimer()
        print("[SessionLock] Entered background at \(backgroundedAt!)")
    }

    func appWillEnterForeground() {
        if let bg = backgroundedAt {
            let elapsed = Date().timeIntervalSince(bg)
            print("[SessionLock] Foreground after \(String(format: "%.1f", elapsed))s (timeout: \(backgroundTimeout)s)")
            if elapsed >= backgroundTimeout {
                lock()
            }
        }
        backgroundedAt = nil
        recordActivity()
        startTimer()
    }

    func lock() {
        guard !isLocked else { return }
        isLocked = true
        stopTimer()
        print("[SessionLock] LOCKED")
    }

    func unlock() {
        isLocked = false
        recordActivity()
        startTimer()
        print("[SessionLock] UNLOCKED")
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkInactivity()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func checkInactivity() {
        guard !isLocked else { return }
        if Date().timeIntervalSince(lastActivity) >= foregroundTimeout {
            print("[SessionLock] Foreground timeout reached")
            lock()
        }
    }
}
