import Foundation

public enum IDDigitalError: Error, LocalizedError {
    // Network Errors
    case noInternetConnection(cause: Error? = nil)
    case timeout(cause: Error? = nil)
    case unknownHost(cause: Error? = nil)
    
    // Server Errors
    case serviceUnavailable(statusCode: Int, responseBody: String?, cause: Error? = nil)
    case badResponse(statusCode: Int, responseBody: String?, cause: Error? = nil)
    case unexpectedResponse(statusCode: Int, responseBody: String?, cause: Error? = nil)

    // SDK Usage Errors
    case notInitialized
    case invalidApiKey(reason: String, cause: Error? = nil)
    case invalidDocument(reason: String, cause: Error? = nil)
    case tooManyAttempts
    case deviceNotAssociated
    case userCannotBeAssociated
    case invalidChallengeId(reason: String, cause: Error? = nil)
    case invalidPin(reason: String, cause: Error? = nil)
    case challengeValidationFailed(cause: Error? = nil)

    // Other Errors
    case cameraPermissionDenied(cause: Error? = nil)
    case userCancelled(cause: Error? = nil)
    case unknown(cause: Error? = nil)

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
        case .userCannotBeAssociated:
            return "This user is not eligible for association."
        case .invalidChallengeId(let reason, _):
            return "Invalid challenge ID: \(reason)"
        case .invalidPin(let reason, _):
            return "Invalid PIN: \(reason)"
        case .challengeValidationFailed:
            return "Challenge validation failed."
            
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
