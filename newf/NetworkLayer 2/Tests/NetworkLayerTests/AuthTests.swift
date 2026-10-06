import Foundation
import Testing
@testable import NetworkLayer

@Suite struct AuthTests {
    let store = InMemoryTokenStore(tokens: oldTokens)

    func makeClient(
        transport: MockTransport,
        refresher: MockRefresher = MockRefresher(),
        onSessionExpired: @escaping @Sendable () async -> Void = {}
    ) -> (APIClient, AuthManager) {
        let auth = AuthManager(store: store, refresher: refresher, onSessionExpired: onSessionExpired)
        let client = APIClient(baseURL: baseURL, auth: auth, transport: transport, sleep: { _ in })
        return (client, auth)
    }

    @Test func sendsBearerTokenAndDecodes() async throws {
        let transport = MockTransport.acceptingOnly("old")
        let (client, _) = makeClient(transport: transport)

        let user = try await client.send(.me)

        #expect(user == User(id: 1, name: "Ada"))
        let request = try #require(await transport.requests.first)
        #expect(request.url?.absoluteString == "https://api.example.com/v1/me")
        #expect(request.bearer == "old")
    }

    @Test func refreshesOn401ThenRetriesWithNewToken() async throws {
        let transport = MockTransport.acceptingOnly("new")
        let refresher = MockRefresher()
        let (client, _) = makeClient(transport: transport, refresher: refresher)

        let user = try await client.send(.me)

        #expect(user.name == "Ada")
        #expect(await transport.requests.map(\.bearer) == ["old", "new"])
        #expect(await refresher.calls == 1)
        #expect(store.load() == newTokens)
    }

    @Test func concurrent401sShareOneRefresh() async throws {
        let transport = MockTransport.acceptingOnly("new")
        let refresher = MockRefresher { _ in
            try await Task.sleep(for: .milliseconds(50))
            return newTokens
        }
        let (client, _) = makeClient(transport: transport, refresher: refresher)

        try await withThrowingTaskGroup(of: User.self) { group in
            for _ in 0..<10 {
                group.addTask { try await client.send(.me) }
            }
            for try await user in group {
                #expect(user.name == "Ada")
            }
        }

        #expect(await refresher.calls == 1)
    }

    @Test func refreshesProactivelyWhenTokenIsAboutToExpire() async throws {
        store.save(AuthTokens(accessToken: "old", refreshToken: "refresh-1", expiresAt: Date().addingTimeInterval(10)))
        let transport = MockTransport.acceptingOnly("new")
        let refresher = MockRefresher()
        let (client, _) = makeClient(transport: transport, refresher: refresher)

        _ = try await client.send(.me)

        #expect(await transport.requests.map(\.bearer) == ["new"])
        #expect(await refresher.calls == 1)
    }

    @Test func rejectedRefreshTokenEndsSession() async throws {
        let expiredCalls = Counter()
        let refresher = MockRefresher { _ in throw NetworkError.httpStatus(code: 400, data: Data()) }
        let (client, auth) = makeClient(
            transport: .acceptingOnly("new"),
            refresher: refresher,
            onSessionExpired: { await expiredCalls.increment() }
        )

        #expect(await errorKind { try await client.send(.me) } == .sessionExpired)
        #expect(store.load() == nil)
        #expect(await auth.isSignedIn == false)
        #expect(await expiredCalls.value == 1)

        // Later requests fail fast without hitting the network or the refresher again.
        #expect(await errorKind { try await client.send(.me) } == .notAuthenticated)
        #expect(await refresher.calls == 1)
    }

    @Test func transientRefreshFailureKeepsSession() async throws {
        let refresher = MockRefresher { _ in throw NetworkError.transport(URLError(.notConnectedToInternet)) }
        let (client, auth) = makeClient(transport: .acceptingOnly("new"), refresher: refresher)

        #expect(await errorKind { try await client.send(.me) } == .transport(.notConnectedToInternet))
        #expect(store.load() == oldTokens)
        #expect(await auth.isSignedIn)
    }

    @Test func still401AfterRefreshFailsWithoutLooping() async throws {
        let transport = MockTransport { _, _ in .status(401) }
        let refresher = MockRefresher()
        let (client, _) = makeClient(transport: transport, refresher: refresher)

        #expect(await errorKind { try await client.send(.me) } == .unauthorized)
        #expect(await transport.requests.count == 2)
        #expect(await refresher.calls == 1)
    }

    @Test func publicEndpointSkipsAuth() async throws {
        let transport = MockTransport { _, _ in .status(401) }
        let refresher = MockRefresher()
        let (client, _) = makeClient(transport: transport, refresher: refresher)

        #expect(await errorKind { try await client.send(.publicProfile) } == .httpStatus(401))
        #expect(await transport.requests.first?.bearer == nil)
        #expect(await refresher.calls == 0)
    }

    @Test func signOutDuringRefreshDoesNotRestoreSession() async throws {
        let refreshStarted = Gate()
        let finishRefresh = Gate()
        let refresher = MockRefresher { _ in
            await refreshStarted.open()
            await finishRefresh.wait()
            return newTokens
        }
        let (client, auth) = makeClient(transport: .acceptingOnly("new"), refresher: refresher)

        let request = Task { await errorKind { try await client.send(.me) } }
        await refreshStarted.wait()
        try await auth.signOut()
        await finishRefresh.open()

        #expect(await request.value == .notAuthenticated)
        #expect(store.load() == nil)
        #expect(await auth.isSignedIn == false)
    }
}
