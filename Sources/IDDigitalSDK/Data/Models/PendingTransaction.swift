import Foundation

/// A pending OIDC transaction found by `IDDigitalSDK.startActiveTransactionPolling`
/// (see .docs/sdk/cliente/09-polling-transaccion-activa.md). No `type` field: this
/// channel only ever covers recurring login (validation) - a device with no
/// association has no bearer token to poll with in the first place, same as
/// how deep link/QR resolve association vs validation locally via `isAssociated()`.
struct PendingTransaction: Decodable, Sendable {
  let id: String
}

struct PendingTransactionsResponse: Decodable, Sendable {
  let transactions: [PendingTransaction]
}
