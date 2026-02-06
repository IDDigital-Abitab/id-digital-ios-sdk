struct ValidationSession: Codable, Sendable {
  let id: String
  let status: String
  let challenges: [Challenge]
  /// Optional fields from API; aligned with Android for future use.
  let type: String?
  let createdAt: String?
  let expirationDate: String?
  let payload: [String: String]?
}
