import SwiftUI

@main
struct BankNetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            RootContentView(coordinator: coordinator)
        }
    }
}
