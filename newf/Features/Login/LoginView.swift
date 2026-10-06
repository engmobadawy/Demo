import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel

    init(coordinator: AppCoordinator) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(coordinator: coordinator))
    }

    var body: some View {
        VStack(spacing: 20) {

            if viewModel.isBiometricEnabled {
                Button(action: {
                    Task { await viewModel.loginWithBiometrics() }
                }) {
                    HStack {
                        Image(systemName: "faceid")
                            .font(.title2)
                        Text("Sign in with Face ID")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(viewModel.isLoading)

                Text("or")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }

            Text("BankNet Login")
                .font(.largeTitle)
                .fontWeight(.bold)

            TextField("Username", text: $viewModel.username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onChange(of: viewModel.username) { _, _ in viewModel.errorMessage = nil }

            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: viewModel.password) { _, _ in viewModel.errorMessage = nil }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                Task { await viewModel.login() }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Login")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.username.isEmpty || viewModel.password.isEmpty ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(viewModel.username.isEmpty || viewModel.password.isEmpty || viewModel.isLoading)
        }
        .padding()
        .alert("Enable Face ID", isPresented: $viewModel.showBiometricSetupPrompt) {
            Button("Not Now", role: .cancel) {
                Task { await viewModel.skipBiometricSetup() }
            }
            Button("Enable") {
                Task { await viewModel.enableBiometrics() }
            }
        } message: {
            Text("Would you like to use Face ID for faster login next time?")
        }
    }
}
