import Foundation

public actor AuthManager {
    private let store: any TokenStore
    private let refresher: any TokenRefresher
    private let refreshLeeway: TimeInterval
    private let now: @Sendable () -> Date
    private let onSessionExpired: @Sendable () async -> Void

    private var tokens: AuthTokens?
    private var refreshTask: Task<AuthTokens, any Error>?
    private var generation = 0

    public init(
        store: any TokenStore,
        refresher: any TokenRefresher,
        refreshLeeway: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = { Date() },
        onSessionExpired: @escaping @Sendable () async -> Void = {}
    ) {
        self.store = store
        self.refresher = refresher
        self.refreshLeeway = refreshLeeway
        self.now = now
        self.onSessionExpired = onSessionExpired
        self.tokens = store.load()
    }

    public var isSignedIn: Bool {
        tokens != nil
    }

    public var currentTokens: AuthTokens? {
        tokens
    }

    public func signIn(with tokens: AuthTokens) throws {
        try store.save(tokens)
        startNewSession(with: tokens)
    }

    public func signOut() throws {
        try store.clear()
        startNewSession(with: nil)
    }

    public func validAccessToken() async throws -> String {
        if let refreshTask {
            return try await refreshTask.value.accessToken
        }
        guard let tokens else { throw NetworkError.notAuthenticated }

        if let expiresAt = tokens.expiresAt, expiresAt <= now().addingTimeInterval(refreshLeeway) {
            return try await refresh(using: tokens.refreshToken).accessToken
        }
        return tokens.accessToken
    }

    func handleUnauthorized(rejectedToken: String) async throws {
        if let refreshTask {
            _ = try await refreshTask.value
            return
        }
        guard let tokens else { throw NetworkError.notAuthenticated }

        guard tokens.accessToken == rejectedToken else { return }
        _ = try await refresh(using: tokens.refreshToken)
    }

    private func refresh(using refreshToken: String) async throws -> AuthTokens {
        let generation = self.generation
        let task = Task {
            defer {
                if self.generation == generation { self.refreshTask = nil }
            }
            do {
                let newTokens = try await refresher.refresh(using: refreshToken)
                guard self.generation == generation else { throw NetworkError.notAuthenticated }
                self.tokens = newTokens
                try? store.save(newTokens)
                return newTokens
            } catch {
                guard self.generation == generation, Self.isRejection(error) else { throw error }
                self.tokens = nil
                try? store.clear()
                await onSessionExpired()
                throw NetworkError.sessionExpired
            }
        }
        refreshTask = task
        return try await task.value
    }

    private func startNewSession(with tokens: AuthTokens?) {
        refreshTask?.cancel()
        refreshTask = nil
        generation += 1
        self.tokens = tokens
    }

    private static func isRejection(_ error: any Error) -> Bool {
        switch error as? NetworkError {
        case .sessionExpired: true
        case .httpStatus(let code, _): [400, 401, 403].contains(code)
        default: false
        }
    }
}
