import Foundation

public struct RetryPolicy: Sendable {
    public var maxAttempts: Int
    public var baseDelay: TimeInterval
    public var maxDelay: TimeInterval
    public var retryableStatusCodes: Set<Int>
    public var retryableMethods: Set<HTTPMethod>

    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 0.5,
        maxDelay: TimeInterval = 10,
        retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504],
        retryableMethods: Set<HTTPMethod> = [.get, .head, .put, .delete]
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.retryableStatusCodes = retryableStatusCodes
        self.retryableMethods = retryableMethods
    }

    public static let `default` = RetryPolicy()
    public static let never = RetryPolicy(maxAttempts: 1)

    func delay(afterAttempt attempt: Int, method: HTTPMethod, statusCode: Int, retryAfter: String?) -> TimeInterval? {
        guard attempt < maxAttempts,
              retryableMethods.contains(method),
              retryableStatusCodes.contains(statusCode)
        else { return nil }

        if let retryAfter, let seconds = Self.parseRetryAfter(retryAfter) {
            return seconds <= maxDelay ? seconds : nil
        }
        return backoff(afterAttempt: attempt)
    }

    func delay(afterAttempt attempt: Int, method: HTTPMethod, error: URLError) -> TimeInterval? {
        guard attempt < maxAttempts else { return nil }

        if Self.requestNotSentCodes.contains(error.code) {
            return backoff(afterAttempt: attempt)
        }
        if Self.requestMaybeSentCodes.contains(error.code), retryableMethods.contains(method) {
            return backoff(afterAttempt: attempt)
        }
        return nil
    }

    private func backoff(afterAttempt attempt: Int) -> TimeInterval {
        let window = min(maxDelay, baseDelay * pow(2, Double(attempt - 1)))
        return .random(in: (window / 2)...window)
    }

    private static let requestNotSentCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
    ]

    private static let requestMaybeSentCodes: Set<URLError.Code> = [
        .timedOut, .networkConnectionLost,
    ]

    static func parseRetryAfter(_ value: String, now: Date = Date()) -> TimeInterval? {
        let value = value.trimmingCharacters(in: .whitespaces)
        if let seconds = TimeInterval(value) {
            return max(0, seconds)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: value) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }
}
