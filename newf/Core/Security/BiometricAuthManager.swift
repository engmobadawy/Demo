import Foundation
import LocalAuthentication

public actor BiometricAuthManager {
    public init() {}

    public func canEvaluatePolicy() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    public func authenticate(reason: String = "Log in to your account") async throws {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw error ?? NSError(domain: "BiometricError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Biometrics not available"])
        }

        let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        if !success {
            throw NSError(domain: "BiometricError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
        }
    }
}
