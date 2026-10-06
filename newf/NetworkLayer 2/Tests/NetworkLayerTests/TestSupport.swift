import Foundation
@testable import NetworkLayer

struct User: Codable, Sendable, Equatable {
    let id: Int
    let name: String
}

extension Endpoint where Response == User {
    static var me: Self { Endpoint(path: "/me") }
    static var publicProfile: Self { Endpoint(path: "/public", requiresAuth: false) }
    static func rename(to name: String) -> Self {
        Endpoint(method: .post, path: "/me", body: ["name": name])
    }
}

let baseURL = URL(string: "https://api.example.com/v1")!
let oldTokens = AuthTokens(accessToken: "old", refreshToken: "refresh-1")
let newTokens = AuthTokens(accessToken: "new", refreshToken: "refresh-2")
let userJSON = Data(#"{"id":1,"name":"Ada"}"#.utf8)

struct Reply: Sendable {
    var status: Int
    var data = Data()
    var headers: [String: String] = [:]

    static func ok(_ data: Data = userJSON) -> Reply { Reply(status: 200, data: data) }
    static func status(_ code: Int, headers: [String: String] = [:]) -> Reply { Reply(status: code, headers: headers) }
}

/// Fake server. The handler gets each request and its 1-based index.
actor MockTransport: HTTPTransport {
    typealias Handler = @Sendable (URLRequest, Int) async throws -> Reply

    private let handler: Handler
    private(set) var requests: [URLRequest] = []

    init(_ handler: @escaping Handler) {
        self.handler = handler
    }

    /// Answers 200 to the new token, 401 to anything else.
    static func acceptingOnly(_ token: String) -> MockTransport {
        MockTransport { request, _ in
            request.bearer == token ? .ok() : .status(401)
        }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let reply = try await handler(request, requests.count)
        let response = HTTPURLResponse(
            url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: reply.headers
        )!
        return (reply.data, response)
    }
}

actor MockRefresher: TokenRefresher {
    typealias Handler = @Sendable (String) async throws -> AuthTokens

    private let handler: Handler
    private(set) var calls = 0

    init(_ handler: @escaping Handler = { _ in newTokens }) {
        self.handler = handler
    }

    func refresh(using refreshToken: String) async throws -> AuthTokens {
        calls += 1
        return try await handler(refreshToken)
    }
}

/// Records retry waits instead of sleeping.
actor SleepRecorder {
    private(set) var delays: [TimeInterval] = []

    nonisolated var sleep: APIClient.Sleep {
        { delay in await self.record(delay) }
    }

    private func record(_ delay: TimeInterval) {
        delays.append(delay)
    }
}

/// One-shot signal for ordering concurrent test steps.
actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}

actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}

extension URLRequest {
    var bearer: String? {
        value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "")
    }
}

/// Equatable view of `NetworkError` for assertions.
enum ErrorKind: Equatable {
    case invalidURL, notAuthenticated, sessionExpired, unauthorized
    case httpStatus(Int)
    case transport(URLError.Code)
    case encoding, decoding, invalidResponse
    case other(String)
}

func errorKind(_ body: () async throws -> some Any) async -> ErrorKind? {
    do {
        _ = try await body()
        return nil
    } catch let error as NetworkError {
        switch error {
        case .invalidURL: return .invalidURL
        case .notAuthenticated: return .notAuthenticated
        case .sessionExpired: return .sessionExpired
        case .unauthorized: return .unauthorized
        case .httpStatus(let code, _): return .httpStatus(code)
        case .transport(let urlError): return .transport(urlError.code)
        case .encoding: return .encoding
        case .decoding: return .decoding
        case .invalidResponse: return .invalidResponse
        }
    } catch {
        return .other("\(error)")
    }
}
