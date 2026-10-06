import Foundation

public enum NetworkError: Error, Sendable {
    case invalidURL
    case notAuthenticated
    case sessionExpired
    case unauthorized
    case httpStatus(code: Int, data: Data)
    case transport(URLError)
    case encoding(any Error)
    case decoding(any Error)
    case invalidResponse
}
