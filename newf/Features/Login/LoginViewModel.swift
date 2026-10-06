import Foundation
import Combine

@MainActor
class LoginViewModel: ObservableObject {
    @Published var username = "amiraahmed"
    @Published var password = "Test@12345"
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var isBiometricAvailable = false
    @Published var isBiometricEnabled = false
    @Published var showBiometricSetupPrompt = false

    private let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        Task { await checkBiometricStatus() }
    }

    func checkBiometricStatus() async {
        isBiometricAvailable = await coordinator.biometricAuthManager.canEvaluatePolicy()
        isBiometricEnabled = UserDefaults.standard.bool(forKey: "biometricEnabled") && isBiometricAvailable
    }

    func loginWithBiometrics() async {
        isLoading = true
        errorMessage = nil

        do {
            try await coordinator.biometricAuthManager.authenticate()

            if let tokens = coordinator.biometricTokenStore.load() {
                try await coordinator.authManager.signIn(with: tokens)
                await coordinator.updateSignInState()
            } else {
                errorMessage = "No biometric credentials found. Please log in with your password."
                isBiometricEnabled = false
                UserDefaults.standard.set(false, forKey: "biometricEnabled")
            }
        } catch {
            errorMessage = "Biometric login failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func login() async {
        isLoading = true
        errorMessage = nil

        do {
            let tokens = try await coordinator.authService.login(username: username, password: password)
            try await coordinator.authManager.signIn(with: tokens)

            if isBiometricAvailable && !isBiometricEnabled {
                showBiometricSetupPrompt = true
            } else {
                await coordinator.updateSignInState()
            }
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func enableBiometrics() async {
        guard let tokens = await coordinator.authManager.currentTokens else { return }
        do {
            try coordinator.biometricTokenStore.save(tokens)
            UserDefaults.standard.set(true, forKey: "biometricEnabled")
            isBiometricEnabled = true
        } catch {
            errorMessage = "Failed to enable biometrics: \(error.localizedDescription)"
        }
        await coordinator.updateSignInState()
    }

    func skipBiometricSetup() async {
        await coordinator.updateSignInState()
    }
}
