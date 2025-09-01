public struct Challenge: Codable, Sendable {
  public let id: String
  public let type: ChallengeType
  public let status: String
  public let expirationDate: String
}
