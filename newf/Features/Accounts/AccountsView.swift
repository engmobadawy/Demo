import SwiftUI

struct AccountsView: View {
    @StateObject private var viewModel: AccountsViewModel

    init(coordinator: AppCoordinator) {
        _viewModel = StateObject(wrappedValue: AccountsViewModel(coordinator: coordinator))
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Fetching accounts...")
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Text(error)
                            .foregroundColor(.red)
                        Button("Retry") {
                            Task { await viewModel.fetchAccounts() }
                        }
                        .padding()
                    }
                } else {
                    List(viewModel.accounts) { account in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(account.acnt_nickname ?? "No Nickname")
                                    .font(.headline)
                                Spacer()
                                Text(account.acnt_currency)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Text(account.acnt_type)
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack {
                                Text("Balance:")
                                    .fontWeight(.medium)
                                Text("\(account.acnt_balance) \(account.acnt_currency)")
                                    .foregroundColor(.green)
                            }

                            Text("IBAN: \(account.iban)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                    .refreshable {
                        await viewModel.fetchAccounts()
                    }
                }
            }
            .navigationTitle("Source Accounts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Logout") {
                        Task { await viewModel.logout() }
                    }
                }
            }
            .task {
                await viewModel.fetchAccounts()
            }
        }
    }
}
