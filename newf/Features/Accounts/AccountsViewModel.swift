import Foundation
import Combine

@MainActor
class AccountsViewModel: ObservableObject {
    @Published var accounts: [BankAccount] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    func fetchAccounts() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let response = try await coordinator.apiClient.send(.sourceAccounts)
            self.accounts = response.accounts
        } catch is CancellationError {
            print("Fetch accounts task was cancelled.")
        } catch {
            errorMessage = "Failed to load accounts: \(error.localizedDescription)"
        }
    }

    func logout() async {
        do {
            try await coordinator.authManager.signOut()
            try? coordinator.biometricTokenStore.clear()
            UserDefaults.standard.set(false, forKey: "biometricEnabled")
            await coordinator.updateSignInState()
        } catch {
            errorMessage = "Logout failed: \(error.localizedDescription)"
        }
    }
}
