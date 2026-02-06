public struct DeviceAssociation: Codable, Sendable {
  public let token: String
  public let document: Document
  public let createdAt: String
  /// ID token from backend; nil until backend sends it. Use placeholder when persisting if nil.
  public let idToken: String?

  public init(token: String, document: Document, createdAt: String, idToken: String? = nil) {
    self.token = token
    self.document = document
    self.createdAt = createdAt
    self.idToken = idToken
  }
}
