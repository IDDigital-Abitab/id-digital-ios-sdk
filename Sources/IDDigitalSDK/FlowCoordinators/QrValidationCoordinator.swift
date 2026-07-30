import UIKit
import FactoryKit
import SwiftUI
import LocalAuthentication

/// QR cross-device variant of `ValidationCoordinator`: identical challenge
/// flow (pin/liveness for a single `ChallengeType`), duplicated on purpose
/// rather than sharing code with it (see .docs/sdk/cliente/08-qr-cross-device.md).
///
/// The only differences are: it starts with a QR scan step to obtain the
/// `transactionId` (an opaque signed token, never parsed/validated here),
/// and on success it completes that OIDC transaction (`CompleteTransactionUseCase`)
/// itself instead of just returning the `validationSessionId` to the
/// Integrator - there is no Integrator round-trip (push/deep link) to do that
/// in this flow, since the citizen scanned the code directly from within this
/// same app.
@MainActor
final class QrValidationCoordinator {
  private let presentingViewController: UIViewController
  private let challengeType: ChallengeType
  private var navigationController: UINavigationController?

  init(presentingViewController: UIViewController, challengeType: ChallengeType) {
    self.presentingViewController = presentingViewController
    self.challengeType = challengeType
  }

  func start() async throws -> String? {
    let transactionId = try await scanQrCode()

    let createUseCase = Container.shared.createValidationSessionUseCase()
    let validationSession = try await createUseCase.execute(type: challengeType)

    guard let challenge = validationSession.challenges.first else {
      throw IDDigitalError.unknown(cause: nil)
    }

    switch challenge.type {
    case .pin:
      try await runPinChallenge(for: challenge)
    case .liveness:
      try await runLivenessChallenge(for: challenge)
    }

    navigationController?.dismiss(animated: true)

    let completeTransactionUseCase = Container.shared.completeTransactionUseCase()
    return try await completeTransactionUseCase.execute(
      transactionId: transactionId,
      validationSessionId: validationSession.id
    )
  }

  private func scanQrCode() async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
      var hasResumed = false

      let scannerView = QRScannerView(
        onScanned: { value in
          if !hasResumed {
            hasResumed = true
            continuation.resume(returning: value)
          }
        },
        onClose: {
          if !hasResumed {
            hasResumed = true
            self.navigationController?.dismiss(animated: true)
            continuation.resume(throwing: IDDigitalError.userCancelled())
          }
        }
      )

      let hostingController = UIHostingController(rootView: scannerView)

      let navController = UINavigationController(rootViewController: hostingController)
      navController.isNavigationBarHidden = true
      self.navigationController = navController
      navController.modalPresentationStyle = .fullScreen
      presentingViewController.present(navController, animated: true)
    }
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
      navigationController?.pushViewController(hostingController, animated: true)
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
      navigationController?.pushViewController(hostingController, animated: true)
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
