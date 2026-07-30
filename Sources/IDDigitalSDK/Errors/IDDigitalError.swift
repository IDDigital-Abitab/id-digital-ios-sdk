import Foundation

/// Errores que puede devolver la API pública de ID Digital.
public enum IDDigitalError: Error, LocalizedError {
    // Network Errors
    /// El dispositivo no tiene conexión a internet.
    case noInternetConnection(cause: Error? = nil)

    /// La operación superó el tiempo máximo de espera.
    case timeout(cause: Error? = nil)

    /// No fue posible resolver el host configurado.
    case unknownHost(cause: Error? = nil)
    
    // Server Errors
    /// El servicio no está disponible temporalmente.
    case serviceUnavailable(statusCode: Int, responseBody: String?, cause: Error? = nil)

    /// ID Digital rechazó la solicitud por datos inválidos.
    case badResponse(statusCode: Int, responseBody: String?, cause: Error? = nil)

    /// ID Digital devolvió una respuesta no contemplada.
    case unexpectedResponse(statusCode: Int, responseBody: String?, cause: Error? = nil)

    // SDK Usage Errors
    /// La operación requiere invocar primero ``IDDigitalSDK/initialize(apiKey:environment:baseUrl:cognitoAppClientIdOverride:)``.
    case notInitialized

    /// La credencial de integración no es válida.
    case invalidApiKey(reason: String, cause: Error? = nil)

    /// El documento recibido no es válido.
    case invalidDocument(reason: String, cause: Error? = nil)

    /// El Usuario agotó los intentos permitidos para el desafío.
    case tooManyAttempts

    /// El dispositivo no tiene una asociación activa.
    case deviceNotAssociated

    /// El identificador de desafío no es válido.
    case invalidChallengeId(reason: String, cause: Error? = nil)

    /// El PIN ingresado no es válido.
    case invalidPin(reason: String, cause: Error? = nil)

    /// El desafío no pudo validarse.
    case challengeValidationFailed(cause: Error? = nil)

    /// La transacción OIDC no existe o dejó de estar disponible.
    case transactionNotFound

    /// La sesión de validación no existe o dejó de estar disponible.
    case validationSessionNotFound

    /// La sesión contiene desafíos que todavía no fueron completados.
    case sessionHasUncompletedChallenges

    /// La transacción y la sesión pertenecen a identidades diferentes.
    case forbidden

    // Other Errors
    /// El Usuario denegó el permiso de cámara requerido para el flujo.
    case cameraPermissionDenied(cause: Error? = nil)

    /// El Usuario canceló la operación.
    case userCancelled(cause: Error? = nil)

    /// Ocurrió un error que la SDK no pudo clasificar.
    case unknown(cause: Error? = nil)

    /// Descripción legible del error.
    public var errorDescription: String? {
        switch self {
        // Network
        case .noInternetConnection:
            return "No internet connection."
        case .timeout:
            return "The connection timed out."
        case .unknownHost:
            return "Could not resolve host."
        
        // Server
        case .serviceUnavailable(let code, _, _):
            return "Service unavailable (code: \(code))."
        case .badResponse(let code, _, _):
            return "Invalid server response (code: \(code))."
        case .unexpectedResponse(let code, _, _):
            return "Unexpected server response (code: \(code))."
            
        // SDK
        case .notInitialized:
            return "IDDigitalSDK has not been initialized. Call initialize() first."
        case .invalidApiKey(let reason, _):
            return "Invalid API Key: \(reason)"
        case .invalidDocument(let reason, _):
            return "Invalid document: \(reason)"
        case .tooManyAttempts:
            return "Too many attempts"
        case .deviceNotAssociated:
            return "Device is not associated."
        case .invalidChallengeId(let reason, _):
            return "Invalid challenge ID: \(reason)"
        case .invalidPin(let reason, _):
            return "Invalid PIN: \(reason)"
        case .challengeValidationFailed:
            return "Challenge validation failed."
        case .transactionNotFound:
            return "OIDC transaction not found."
        case .validationSessionNotFound:
            return "Validation session not found."
        case .sessionHasUncompletedChallenges:
            return "Validation session has uncompleted challenges."
        case .forbidden:
            return "Forbidden: transaction and validation session belong to different citizens."
            
        // Other
        case .cameraPermissionDenied:
            return "Camera permission was denied."
        case .userCancelled:
            return "The user cancelled the operation."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}
