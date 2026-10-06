import SwiftUI

struct RootContentView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        Group {
            if coordinator.isSignedIn && !coordinator.isLocked {
                AccountsView(coordinator: coordinator)
            } else {
                LoginView(coordinator: coordinator)
            }
        }
    }
}
