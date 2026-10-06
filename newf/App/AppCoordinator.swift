import Foundation
import Combine

@MainActor
class AppCoordinator: ObservableObject {
    let authService: BankNetAuthService
    let biometricAuthManager: BiometricAuthManager
    let biometricTokenStore: BiometricKeychainTokenStore
    let lockManager = SessionLockManager.shared

    @Published var isSignedIn: Bool = false
    @Published var isLocked: Bool = false

    private let baseURL: URL
    private let clientID: String
    private var cancellables = Set<AnyCancellable>()

    lazy var authManager: AuthManager = {
        let store = KeychainTokenStore()
        let refresher = BankNetTokenRefresher(baseURL: baseURL, clientID: clientID)
        return AuthManager(
            store: store,
            refresher: refresher,
            onSessionExpired: { [weak self] in
                await MainActor.run {
                    self?.isSignedIn = false
                }
            }
        )
    }()

    lazy var apiClient: APIClient = {
        return APIClient(baseURL: baseURL, auth: authManager)
    }()

    init() {
        self.baseURL = URL(string: "https://rp.intercom.com.eg:446")!
        self.clientID = "09dp6vn4VLba4OFZ3dLT"

        self.authService = BankNetAuthService(baseURL: baseURL, clientID: clientID)
        self.biometricAuthManager = BiometricAuthManager()
        self.biometricTokenStore = BiometricKeychainTokenStore()

        lockManager.$isLocked
            .sink { [weak self] locked in
                self?.isLocked = locked
            }
            .store(in: &cancellables)

        Task {
            let hasBiometricEnabled = UserDefaults.standard.bool(forKey: "biometricEnabled")
            if hasBiometricEnabled {
                self.isSignedIn = false
            } else {
                self.isSignedIn = await authManager.isSignedIn
            }
        }
    }

    func updateSignInState() async {
        self.isSignedIn = await authManager.isSignedIn
        if self.isSignedIn {
            lockManager.unlock()
        }
    }
}
