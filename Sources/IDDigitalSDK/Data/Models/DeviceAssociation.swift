/// Asociación activa entre el dispositivo y una identidad de ID Digital.
public struct DeviceAssociation: Codable, Sendable {
  /// Token utilizado por la SDK para autenticar operaciones de la asociación.
  public let token: String

  /// Documento vinculado a la asociación.
  public let document: Document

  /// Fecha de creación informada por ID Digital.
  public let createdAt: String

  /// ID Token OIDC emitido para la asociación, o `nil` si no fue incluido.
  public let idToken: String?

  /// Crea el modelo de una asociación de dispositivo.
  ///
  /// La SDK construye normalmente esta instancia a partir de la respuesta de ID Digital.
  ///
  /// - Parameters:
  ///   - token: Token de autenticación de la asociación.
  ///   - document: Documento vinculado.
  ///   - createdAt: Fecha de creación informada por ID Digital.
  ///   - idToken: ID Token OIDC opcional.
  public init(token: String, document: Document, createdAt: String, idToken: String? = nil) {
    self.token = token
    self.document = document
    self.createdAt = createdAt
    self.idToken = idToken
  }
}
