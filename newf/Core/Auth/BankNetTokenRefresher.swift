import Foundation

public struct BankNetTokenRefresher: TokenRefresher {
    private let baseURL: URL
    private let clientID: String
    private let transport: any HTTPTransport

    public init(
        baseURL: URL,
        clientID: String,
        transport: any HTTPTransport = URLSessionTransport()
    ) {
        self.baseURL = baseURL
        self.clientID = clientID
        self.transport = transport
    }

    public func refresh(using refreshToken: String) async throws -> AuthTokens {
        let url = baseURL.appending(path: "/mga/sps/oauth/oauth20/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "grant_type": "refresh_token",
            "client_id": clientID,
            "refresh_token": refreshToken
        ]
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await transport.send(request)

        guard (200..<300).contains(response.statusCode) else {
            if [400, 401, 403].contains(response.statusCode) {
                throw NetworkError.sessionExpired
            }
            throw NetworkError.httpStatus(code: response.statusCode, data: data)
        }

        do {
            let tokenResponse = try JSONDecoder().decode(BankNetTokenResponse.self, from: data)
            return tokenResponse.toAuthTokens()
        } catch {
            throw NetworkError.decoding(error)
        }
    }
}
