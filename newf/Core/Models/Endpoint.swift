import Foundation

public struct Endpoint<Response: Decodable & Sendable>: Sendable {
    public var method: HTTPMethod
    public var path: String
    public var queryItems: [URLQueryItem]
    public var headers: [String: String]
    public var body: (any Encodable & Sendable)?
    public var requiresAuth: Bool
    public var retryPolicy: RetryPolicy?

    public init(
        method: HTTPMethod = .get,
        path: String,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: (any Encodable & Sendable)? = nil,
        requiresAuth: Bool = true,
        retryPolicy: RetryPolicy? = nil
    ) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.requiresAuth = requiresAuth
        self.retryPolicy = retryPolicy
    }
}
