struct Challenge: Codable, Sendable {
  let id: String
  let type: ChallengeType
  let status: String
  let expirationDate: String
}
