import Foundation

/// Ambiente de ID Digital utilizado por la SDK.
public enum IDDigitalSDKEnvironment: Sendable {
    /// Ambiente de pruebas y validación de integraciones.
    case staging

    /// Ambiente productivo de ID Digital.
    case production
}
