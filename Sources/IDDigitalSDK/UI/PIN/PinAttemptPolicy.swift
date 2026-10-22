import Foundation

enum PinFailureAction {
  case showWrongPin
  case close(IDDigitalError)
  case stay
}

enum PinAttemptPolicy {
  static let maxInvalidAttempts = 3

  /// Cuenta solo `invalid-pin`. Al tercero cierra sin otro `validate`.
  /// `too-many-attempts` y un 400 de challenge ya terminado cierran en el acto.
  /// Red, timeout y 5xx no suman y no se muestran como PIN incorrecto.
  static func action(for error: Error, invalidAttempts: Int) -> (PinFailureAction, Int) {
    if let terminal = terminalChallengeError(error) {
      return (.close(terminal), invalidAttempts)
    }
    if case IDDigitalError.invalidPin = error {
      let next = invalidAttempts + 1
      if next >= maxInvalidAttempts {
        return (.close(.challengeValidationFailed(cause: error)), next)
      }
      return (.showWrongPin, next)
    }
    return (.stay, invalidAttempts)
  }

  private static func terminalChallengeError(_ error: Error) -> IDDigitalError? {
    guard let idError = error as? IDDigitalError else { return nil }
    switch idError {
    case .tooManyAttempts:
      return idError
    case .badResponse(let statusCode, _, _) where statusCode == 400:
      return idError
    default:
      return nil
    }
  }
}
