/// Documento de identidad asociado al dispositivo.
public struct Document: Codable, Sendable {
  /// Número del documento.
  public let number: String

  /// Tipo de documento acordado con ID Digital, por ejemplo `ci`.
  public let type: String

  /// Código de país del documento, por ejemplo `UY`.
  public let country: String

  /// Crea un documento de identidad.
  ///
  /// - Parameters:
  ///   - number: Número del documento.
  ///   - type: Tipo de documento.
  ///   - country: Código de país del documento.
  public init(number: String, type: String, country: String) {
    self.number = number
    self.type = type
    self.country = country
  }
}
