public struct DeviceAssociation: Codable, Sendable {
  public let token: String
  public let document: Document
  public let createdAt: String
  /// OIDC ID Token (JWT) when the backend client has an active secret; `nil` if omitted.
  public let idToken: String?

  public init(token: String, document: Document, createdAt: String, idToken: String? = nil) {
    self.token = token
    self.document = document
    self.createdAt = createdAt
    self.idToken = idToken
  }
}
