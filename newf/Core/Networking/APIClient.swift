import Foundation

public struct APIClient: Sendable {
    public typealias Sleep = @Sendable (TimeInterval) async throws -> Void

    private let baseURL: URL
    private let auth: AuthManager?
    private let transport: any HTTPTransport
    private let defaultHeaders: [String: String]
    private let retryPolicy: RetryPolicy
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let sleep: Sleep

    public init(
        baseURL: URL,
        auth: AuthManager? = nil,
        transport: any HTTPTransport = URLSessionTransport(),
        defaultHeaders: [String: String] = ["Accept": "application/json"],
        retryPolicy: RetryPolicy = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        sleep: @escaping Sleep = { try await Task.sleep(for: .seconds($0)) }
    ) {
        self.baseURL = baseURL
        self.auth = auth
        self.transport = transport
        self.defaultHeaders = defaultHeaders
        self.retryPolicy = retryPolicy
        self.encoder = encoder
        self.decoder = decoder
        self.sleep = sleep
    }

    public func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        let data = try await data(for: endpoint)
        if let empty = EmptyResponse() as? Response {
            return empty
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw NetworkError.decoding(error)
        }
    }

    public func data<Response>(for endpoint: Endpoint<Response>) async throws -> Data {
        let baseRequest = try makeRequest(for: endpoint)
        let policy = endpoint.retryPolicy ?? retryPolicy
        var attempt = 1
        var didRefresh = false

        while true {
            try Task.checkCancellation()

            var request = baseRequest
            var sentToken: String?
            if endpoint.requiresAuth {
                guard let auth else { throw NetworkError.notAuthenticated }
                let token = try await auth.validAccessToken()
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                sentToken = token
            }

            let data: Data
            let response: HTTPURLResponse
            do {
                (data, response) = try await transport.send(request)
            } catch let error as URLError {
                if error.code == .cancelled { throw CancellationError() }
                guard let delay = policy.delay(afterAttempt: attempt, method: endpoint.method, error: error) else {
                    throw NetworkError.transport(error)
                }
                try await sleep(delay)
                attempt += 1
                continue
            }

            if (200..<300).contains(response.statusCode) {
                return data
            }

            if response.statusCode == 401, let auth, let sentToken {
                guard !didRefresh else { throw NetworkError.unauthorized }
                didRefresh = true
                try await auth.handleUnauthorized(rejectedToken: sentToken)
                continue
            }

            let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
            guard let delay = policy.delay(
                afterAttempt: attempt,
                method: endpoint.method,
                statusCode: response.statusCode,
                retryAfter: retryAfter
            ) else {
                throw NetworkError.httpStatus(code: response.statusCode, data: data)
            }
            try await sleep(delay)
            attempt += 1
        }
    }

    private func makeRequest<Response>(for endpoint: Endpoint<Response>) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appending(path: endpoint.path),
            resolvingAgainstBaseURL: false
        ) else { throw NetworkError.invalidURL }
        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }
        guard let url = components.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        for (field, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }
        for (field, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        if let body = endpoint.body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw NetworkError.encoding(error)
            }
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        return request
    }
}
