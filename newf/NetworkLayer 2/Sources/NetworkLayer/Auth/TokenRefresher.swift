/// Exchanges a refresh token for new tokens. Usually one POST to your auth server.
///
/// How errors are treated by `AuthManager`:
/// - `NetworkError.sessionExpired`, or `NetworkError.httpStatus` 400/401/403
///   (OAuth `invalid_grant` is 400): the refresh token is dead. The session is cleared.
/// - Anything else (offline, 5xx): tokens are kept so a later request can try again.
public protocol TokenRefresher: Sendable {
    func refresh(using refreshToken: String) async throws -> AuthTokens
}
