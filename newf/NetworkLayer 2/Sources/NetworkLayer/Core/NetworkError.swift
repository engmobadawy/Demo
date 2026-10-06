import Foundation

public enum NetworkError: Error, Sendable {
    /// The endpoint could not be turned into a valid URL.
    case invalidURL
    /// The request needs auth but there is no session. Show login.
    case notAuthenticated
    /// The server rejected the refresh token. Tokens were cleared. Show login.
    case sessionExpired
    /// Still 401 after a successful refresh (for example a missing permission).
    case unauthorized
    /// Non-2xx status that was not retried, or retries ran out.
    case httpStatus(code: Int, data: Data)
    /// Connectivity failure from URLSession, after retries ran out.
    case transport(URLError)
    case encoding(any Error)
    case decoding(any Error)
    /// The transport returned something other than an HTTP response.
    case invalidResponse
}
