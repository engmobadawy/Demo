import Foundation

nonisolated struct AccountsResponse: Decodable, Sendable {
    let result: String
    let accounts: [BankAccount]
}

nonisolated struct BankAccount: Decodable, Identifiable, Sendable {
    var id: String { acnt_identifier }
    let acnt_type: String
    let acnt_nickname: String?
    let acnt_totalBalance: String
    let acnt_number: String
    let currencyName: String
    let acnt_balance: String
    let iban: String
    let acnt_identifier: String
    let acnt_currency: String
}
