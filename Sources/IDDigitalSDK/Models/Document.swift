public struct Document: Codable, Sendable {
  public let number: String
  public let type: String
  public let country: String

  public init(number: String, type: String, country: String) {
    self.number = number
    self.type = type
    self.country = country
  }
}
