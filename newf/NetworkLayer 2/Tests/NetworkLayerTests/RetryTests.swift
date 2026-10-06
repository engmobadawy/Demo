import Foundation
import Testing
@testable import NetworkLayer

@Suite struct RetryTests {
    let sleeper = SleepRecorder()

    func makeClient(transport: MockTransport, policy: RetryPolicy = .default) -> APIClient {
        let auth = AuthManager(store: InMemoryTokenStore(tokens: oldTokens), refresher: MockRefresher())
        return APIClient(baseURL: baseURL, auth: auth, transport: transport, retryPolicy: policy, sleep: sleeper.sleep)
    }

    @Test func retriesServerErrorUntilSuccess() async throws {
        let transport = MockTransport { _, index in index < 3 ? .status(503) : .ok() }
        let client = makeClient(transport: transport)

        _ = try await client.send(.me)

        #expect(await transport.requests.count == 3)
        let delays = await sleeper.delays
        #expect(delays.count == 2)
        // Equal jitter: retry n waits between half and all of baseDelay * 2^(n-1).
        #expect((0.25...0.5).contains(delays[0]))
        #expect((0.5...1.0).contains(delays[1]))
    }

    @Test func stopsAfterMaxAttempts() async throws {
        let transport = MockTransport { _, _ in .status(500) }
        let client = makeClient(transport: transport)

        #expect(await errorKind { try await client.send(.me) } == .httpStatus(500))
        #expect(await transport.requests.count == 3)
    }

    @Test func doesNotRetryClientErrors() async throws {
        let transport = MockTransport { _, _ in .status(404) }
        let client = makeClient(transport: transport)

        #expect(await errorKind { try await client.send(.me) } == .httpStatus(404))
        #expect(await transport.requests.count == 1)
    }

    @Test func doesNotRetryPostOnServerError() async throws {
        let transport = MockTransport { _, _ in .status(503) }
        let client = makeClient(transport: transport)

        #expect(await errorKind { try await client.send(.rename(to: "Bo")) } == .httpStatus(503))
        #expect(await transport.requests.count == 1)
    }

    @Test func retriesPostWhenRequestNeverLeftDevice() async throws {
        let transport = MockTransport { _, index in
            if index == 1 { throw URLError(.cannotConnectToHost) }
            return .ok()
        }
        let client = makeClient(transport: transport)

        _ = try await client.send(.rename(to: "Bo"))

        #expect(await transport.requests.count == 2)
    }

    @Test func doesNotRetryPostOnTimeout() async throws {
        let transport = MockTransport { _, _ in throw URLError(.timedOut) }
        let client = makeClient(transport: transport)

        #expect(await errorKind { try await client.send(.rename(to: "Bo")) } == .transport(.timedOut))
        #expect(await transport.requests.count == 1)
    }

    @Test func honorsRetryAfter() async throws {
        let transport = MockTransport { _, index in
            index == 1 ? .status(429, headers: ["Retry-After": "2"]) : .ok()
        }
        let client = makeClient(transport: transport)

        _ = try await client.send(.me)

        #expect(await sleeper.delays == [2])
    }

    @Test func givesUpWhenRetryAfterExceedsMaxDelay() async throws {
        let transport = MockTransport { _, _ in .status(503, headers: ["Retry-After": "120"]) }
        let client = makeClient(transport: transport)

        #expect(await errorKind { try await client.send(.me) } == .httpStatus(503))
        #expect(await sleeper.delays.isEmpty)
    }

    @Test func endpointPolicyOverridesClientPolicy() async throws {
        let transport = MockTransport { _, _ in .status(503) }
        let client = makeClient(transport: transport)
        var endpoint = Endpoint<User>.me
        endpoint.retryPolicy = .never

        #expect(await errorKind { try await client.send(endpoint) } == .httpStatus(503))
        #expect(await transport.requests.count == 1)
    }

    @Test func parsesRetryAfterHTTPDate() {
        let now = Date(timeIntervalSince1970: 1_445_412_480) // Wed, 21 Oct 2015 07:28:00 GMT
        #expect(RetryPolicy.parseRetryAfter("Wed, 21 Oct 2015 07:28:30 GMT", now: now) == 30)
        #expect(RetryPolicy.parseRetryAfter("soon", now: now) == nil)
    }
}

@Suite struct ResponseTests {
    @Test func emptyResponseSkipsDecoding() async throws {
        let transport = MockTransport { _, _ in Reply(status: 204) }
        let client = APIClient(baseURL: baseURL, transport: transport)

        let result = try await client.send(Endpoint<EmptyResponse>(method: .delete, path: "/session", requiresAuth: false))

        #expect(result == EmptyResponse())
    }

    @Test func badJSONIsDecodingError() async throws {
        let transport = MockTransport { _, _ in .ok(Data("{}".utf8)) }
        let client = APIClient(baseURL: baseURL, transport: transport)

        #expect(await errorKind { try await client.send(.publicProfile) } == .decoding)
    }

    @Test func encodesBodyAsJSON() async throws {
        let transport = MockTransport { _, _ in .ok() }
        let auth = AuthManager(store: InMemoryTokenStore(tokens: oldTokens), refresher: MockRefresher())
        let client = APIClient(baseURL: baseURL, auth: auth, transport: transport)

        _ = try await client.send(.rename(to: "Bo"))

        let request = try #require(await transport.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.httpBody == Data(#"{"name":"Bo"}"#.utf8))
    }
}
