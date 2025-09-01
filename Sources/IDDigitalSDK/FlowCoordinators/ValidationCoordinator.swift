import UIKit
import FactoryKit
import SwiftUI
import LocalAuthentication

@MainActor
final class ValidationCoordinator {
  private let presentingViewController: UIViewController
  private let challengeType: ChallengeType
  private var navigationController: UINavigationController?
  
  init(presentingViewController: UIViewController, challengeType: ChallengeType) {
    self.presentingViewController = presentingViewController
    self.challengeType = challengeType
  }
  
  func start() async throws {
    let createUseCase = Container.shared.createValidationSessionUseCase()
    let validationSession = try await createUseCase.execute(type: challengeType)
    
    guard let challenge = validationSession.challenges.first else {
      throw IDDigitalError.unknown(cause: nil)
    }
    
    let dummyVC = UIViewController()
    let navController = UINavigationController(rootViewController: dummyVC)
    self.navigationController = navController
    navController.isNavigationBarHidden = true
    navController.modalPresentationStyle = .fullScreen
    presentingViewController.present(navController, animated: true)
    
    switch challenge.type {
    case .pin:
      try await runPinChallenge(for: challenge)
    case .liveness:
      try await runLivenessChallenge(for: challenge)
    }
    
    navigationController?.dismiss(animated: true)
  }
  
  private func runPinChallenge(for challenge: Challenge) async throws {
    let executePinUseCase = Container.shared.executePinChallengeUseCase()
    let pinManager = Container.shared.pinDataStoreManager()
    
    let backendPinLastUpdated = try await executePinUseCase.execute(challengeId: challenge.id)
    let localLastBiometricUsage = await pinManager.getLastBiometricUsage()
    
    var pinRecentlyChanged = false
    if let backendDate = backendPinLastUpdated, let localDate = localLastBiometricUsage {
      pinRecentlyChanged = backendDate > localDate
    }
    
    let (_, _) = try await presentPinEntry(
      challengeId: challenge.id,
      shouldShowBiometricToggle: false,
      pinRecentlyChanged: pinRecentlyChanged
    )
    
    await pinManager.saveLastBiometricUsage()
  }
  
  private func presentPinEntry(challengeId: String, shouldShowBiometricToggle: Bool, pinRecentlyChanged: Bool) async throws -> (String, Bool) {
    let pinManager = Container.shared.pinDataStoreManager()
    let isBiometricEnabled = await pinManager.isBiometricPinEnabled()
    
    return try await withCheckedThrowingContinuation { continuation in
      var hasResumed = false
      let pinView = PinEntryView(
        challengeId: challengeId,
        onComplete: { pin, saveBiometrics in
          if !hasResumed { hasResumed = true; continuation.resume(returning: (pin, saveBiometrics)) }
        },
        onBiometric: {
          self.runBiometricAuthentication(challengeId: challengeId, continuation: continuation)
        },
        onBack: {
          if !hasResumed { hasResumed = true; self.navigationController?.dismiss(animated: true); continuation.resume(throwing: IDDigitalError.userCancelled()) }
        },
        onClose: {
          if !hasResumed { hasResumed = true; self.navigationController?.dismiss(animated: true); continuation.resume(throwing: IDDigitalError.userCancelled()) }
        },
        onTooManyAttempts: {
          continuation.resume(throwing: IDDigitalError.tooManyAttempts)
        },
        shouldShowBiometricToggle: shouldShowBiometricToggle,
        isBiometricEnabled: isBiometricEnabled,
        pinRecentlyChanged: pinRecentlyChanged
      )
      
      let hostingController = UIHostingController(rootView: pinView)
      navigationController?.setViewControllers([hostingController], animated: false)
    }
  }
  
  private func runLivenessChallenge(for challenge: Challenge) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      var hasResumed = false
      let livenessView = LivenessFlowView(
        challengeId: challenge.id,
        onComplete: {
          if !hasResumed { hasResumed = true; continuation.resume() }
        },
        onBack: {
          if !hasResumed { hasResumed = true; self.navigationController?.dismiss(animated: true); continuation.resume(throwing: IDDigitalError.userCancelled()) }
        },
        onClose: {
          if !hasResumed { hasResumed = true; self.navigationController?.dismiss(animated: true); continuation.resume(throwing: IDDigitalError.userCancelled()) }
        }
      )
      
      let hostingController = UIHostingController(rootView: livenessView)
      navigationController?.setViewControllers([hostingController], animated: false)
    }
  }
  
  private func runBiometricAuthentication(challengeId: String, continuation: CheckedContinuation<(String, Bool), Error>) {
          Task {
              let context = LAContext()
              var error: NSError?

              if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                  let reason = "Usa tus datos biométricos para completar el PIN"
                  do {
                      let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                      if success {
                          let pinManager = Container.shared.pinDataStoreManager()
                          if let pin = await pinManager.getDecryptedPin() {
                              let validateUseCase = Container.shared.validatePinChallengeUseCase()
                              try await validateUseCase.execute(challengeId: challengeId, pin: pin)
                              
                              await pinManager.saveLastBiometricUsage()
                              continuation.resume(returning: (pin, false))
                          } else {
                              continuation.resume(throwing: IDDigitalError.unknown(cause: nil))
                          }
                      }
                  } catch {
                      // User cancelled, do nothing to allow them to try again.
                  }
              }
          }
      }
}
