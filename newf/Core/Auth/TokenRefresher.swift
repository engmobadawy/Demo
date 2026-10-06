import Foundation

public protocol TokenRefresher: Sendable {
    func refresh(using refreshToken: String) async throws -> AuthTokens
}
