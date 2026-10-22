import SwiftUI
@_implementationOnly import FactoryKit

struct LivenessFlowView: View {
  let challengeId: String

  private let maxValidationAttempts = 3

  @State private var currentScreen: LivenessScreen = .instructions
  @State private var livenessSessionId: String? = nil
  @State private var validationFailures = 0
  @State private var didExhaustAttempts = false
  @State private var didStartValidation = false

  var onComplete: () -> Void
  var onBack: () -> Void
  var onClose: () -> Void
  var onAttemptsExhausted: (IDDigitalError) -> Void
  
  var body: some View {
    VStack {
      switch currentScreen {
      case .instructions:
        LivenessInstructionsScreen(
          onStart: {
            Task {
              do {
                let executeLivenessUseCase = Container.shared.executeLivenessChallengeUseCase()
                self.livenessSessionId = try await executeLivenessUseCase.execute(challengeId: self.challengeId)
                self.currentScreen = .detector
              } catch {
                self.handleExecuteFailure(error)
              }
            }
          },
          onBack: onBack,
          onClose: onClose
        )
      case .detector:
        if let sessionId = livenessSessionId {
          LivenessDetectorView(
            sessionId: sessionId,
            onComplete: {
              self.currentScreen = .validating
            },
            onError: { error in
              print("error in liveness", error)
              self.currentScreen = .error
            }
          )
        } else {
          ProgressView()
        }
      case .validating:
        LoadingView()
          .onAppear {
            guard !didStartValidation else { return }
            didStartValidation = true
            Task {
              do {
                let validateLivenessUseCase = Container.shared.validateLivenessChallengeUseCase()
                _ = try await validateLivenessUseCase.execute(challengeId: self.challengeId)
                self.currentScreen = .completed
              } catch {
                self.registerValidationFailure(error)
              }
            }
          }
      case .error:
        LivenessErrorScreen(
          onRetry: {
            self.livenessSessionId = nil
            self.didStartValidation = false
            self.currentScreen = .instructions
          },
          onClose: onClose
        )
      case .completed:
        LoadingView()
          .onAppear(perform: onComplete)
      }
    }
  }

  /// Un challenge que ya no se puede ejecutar cierra el flujo: reintentar
  /// vuelve a fallar antes de abrir la cámara. Un corte de red o un permiso
  /// de cámara denegado sigue ofreciendo reintento y no cuenta como validación.
  private func handleExecuteFailure(_ error: Error) {
    if let terminal = terminalChallengeError(error) {
      exhaust(terminal)
    } else {
      currentScreen = .error
    }
  }

  /// Igual que Android: solo cuenta el resultado de validate. Al tercer fallo
  /// cierra la prueba de vida en lugar de volver a instrucciones.
  private func registerValidationFailure(_ error: Error) {
    if let terminal = terminalChallengeError(error) {
      exhaust(terminal)
      return
    }
    validationFailures += 1
    if validationFailures >= maxValidationAttempts {
      exhaust(.challengeValidationFailed(cause: error))
    } else {
      currentScreen = .error
    }
  }

  /// `expired-challenge`, `too-many-attempts` o un 400 de challenge ya terminado.
  /// En esos casos el backend no crea otra sesión de liveness.
  private func terminalChallengeError(_ error: Error) -> IDDigitalError? {
    guard let idError = error as? IDDigitalError else { return nil }
    switch idError {
    case .tooManyAttempts, .expiredChallenge:
      return idError
    case .badResponse(let statusCode, _, _) where statusCode == 400:
      return idError
    default:
      return nil
    }
  }

  private func exhaust(_ error: IDDigitalError) {
    guard !didExhaustAttempts else { return }
    didExhaustAttempts = true
    onAttemptsExhausted(error)
  }
}

// Enum to represent the different screens in the liveness flow
enum LivenessScreen {
  case instructions
  case detector
  case validating
  case error
  case completed
}

