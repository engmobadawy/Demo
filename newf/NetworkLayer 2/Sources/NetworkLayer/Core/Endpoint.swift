import Foundation

/// One API call and the type its response decodes to.
///
/// Define endpoints as static factories so call sites stay short:
/// ```swift
/// extension Endpoint where Response == User {
///     static var me: Self { Endpoint(path: "/me") }
/// }
///
/// let user = try await client.send(.me)
/// ```
public struct Endpoint<Response: Decodable & Sendable>: Sendable {
    public var method: HTTPMethod
    public var path: String
    public var queryItems: [URLQueryItem]
    public var headers: [String: String]
    /// Encoded as JSON with the client's encoder.
    public var body: (any Encodable & Sendable)?
    /// Attach the bearer token and refresh it on 401.
    public var requiresAuth: Bool
    /// Overrides the client's default retry policy for this endpoint.
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

/// Use as `Response` for endpoints that return no body (for example 204).
public struct EmptyResponse: Decodable, Sendable, Equatable {
    public init() {}
}
