import Foundation

extension Endpoint where Response == AccountsResponse {
    /// GET /api/bn/rs/ft/it/pre
    static var sourceAccounts: Self {
        Endpoint(
            method: .get,
            path: "/api/bn/rs/ft/it/pre",
            headers: [
                "ch": "05",
                "lang": "en"
            ],
            requiresAuth: true
        )
    }
}
