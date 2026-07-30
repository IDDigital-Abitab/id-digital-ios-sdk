/// Tipo de desafío de autenticación que presenta la SDK.
public enum ChallengeType: String, Codable, Sendable {
    /// Prueba de vida mediante la cámara del dispositivo.
    case liveness

    /// Verificación mediante el PIN de ID Digital.
    case pin
}
