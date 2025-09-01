import Foundation

public extension Error {
    /// Converts a generic Error into a specific IDDigitalError.
    func toIDDigitalError() -> IDDigitalError {
        if let idError = self as? IDDigitalError {
            return idError
        }
        
        let nsError = self as NSError
        switch nsError.domain {
        case NSURLErrorDomain:
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return .noInternetConnection(cause: self)
            case NSURLErrorTimedOut:
                return .timeout(cause: self)
            case NSURLErrorCannotFindHost:
                return .unknownHost(cause: self)
            default:
                return .unknown(cause: self)
            }
        default:
            return .unknown(cause: self)
        }
    }
}
