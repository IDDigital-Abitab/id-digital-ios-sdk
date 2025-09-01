import UIKit
import FactoryKit
import SwiftUI
import LocalAuthentication

@MainActor
final class DeviceAssociationCoordinator {
  private let presentingViewController: UIViewController
  private let document: Document
  private var navigationController: UINavigationController?
  
  init(presentingViewController: UIViewController, document: Document) {
    self.presentingViewController = presentingViewController
    self.document = document
  }
  
  func start() async throws -> String {
    let validationSession = try await startDeviceAssociation()
    
    var pinResult: (pin: String, saveBiometrics: Bool)?
    
    for challenge in validationSession.challenges {
      switch challenge.type {
      case .pin:
        pinResult = try await runPinChallenge(for: challenge)
      case .liveness:
        try await runLivenessChallenge(for: challenge)
      }
    }
    
    let completeAssociationUseCase = Container.shared.completeDeviceAssociationUseCase()
    let newDeviceAssociation = try await completeAssociationUseCase.execute(id: validationSession.id)
    
    try await IDDigitalSDK.shared.removeAssociation()
    
    let storage = Container.shared.deviceAssociationStorage()
    await storage.save(association: newDeviceAssociation)
    
    if let result = pinResult, result.saveBiometrics {
      let pinManager = Container.shared.pinDataStoreManager()
      await pinManager.savePinAndBiometricPreference(pin: result.pin, isEnabled: true)
    }
    
    try await presentSuccess()
    navigationController?.dismiss(animated: true)
    
    return newDeviceAssociation.token
  }
  
  private func startDeviceAssociation() async throws -> ValidationSession {
    return try await withCheckedThrowingContinuation { continuation in
      var hasResumed = false
      
      let instructionsView = DeviceAssociationInstructionsView(
        onStart: {
          Task {
            do {
              let checkUseCase = Container.shared.checkCanAssociateUseCase()
              let createUseCase = Container.shared.createDeviceAssociationUseCase()
              
              let canAssociate = try await checkUseCase.execute(document: self.document)
              if !canAssociate {
                throw IDDigitalError.userCannotBeAssociated
              }
              let session = try await createUseCase.execute(document: self.document)
              
              if !hasResumed {
                hasResumed = true
                continuation.resume(returning: session)
              }
            } catch {
              if !hasResumed {
                hasResumed = true
                continuation.resume(throwing: error)
              }
            }
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
      
      let hostingController = UIHostingController(rootView: instructionsView)
      
      let navController = UINavigationController(rootViewController: hostingController)
      navController.isNavigationBarHidden = true
      self.navigationController = navController
      navController.modalPresentationStyle = .fullScreen
      presentingViewController.present(navController, animated: true)
    }
  }
  
  private func runPinChallenge(for challenge: Challenge) async throws -> (String, Bool) {
    let executePinUseCase = Container.shared.executePinChallengeUseCase()
    let pinLastUpdated = try await executePinUseCase.execute(challengeId: challenge.id)
    
    return try await presentPinEntry(
      challengeId: challenge.id,
      shouldShowBiometricToggle: true,
      pinLastUpdated: pinLastUpdated
    )
    
  }
  
  private func presentPinEntry(challengeId: String, shouldShowBiometricToggle: Bool, pinLastUpdated: Date?) async throws -> (String, Bool) {
    let pinManager = Container.shared.pinDataStoreManager()
    let isBiometricEnabled = await pinManager.isBiometricPinEnabled()
    let pinRecentlyChanged = pinLastUpdated != nil
    
    return try await withCheckedThrowingContinuation { continuation in
      var hasResumed = false
      let pinView = PinEntryView(
        challengeId: challengeId,
        onComplete: { pin, saveBiometrics in
          if !hasResumed {
            hasResumed = true
            continuation.resume(returning: (pin, saveBiometrics))
          }
        },
        onBiometric: { },
        onBack: {
          if !hasResumed {
            hasResumed = true
            self.navigationController?.popViewController(animated: true)
            continuation.resume(throwing: IDDigitalError.userCancelled())
          }
        },
        onClose: {
          if !hasResumed {
            hasResumed = true
            self.navigationController?.dismiss(animated: true)
            continuation.resume(throwing: IDDigitalError.userCancelled())
          }
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
          if !hasResumed {
            hasResumed = true
            continuation.resume()
          }
        },
        onBack: {
          if !hasResumed {
            hasResumed = true
            self.navigationController?.popViewController(animated: true)
            continuation.resume(throwing: IDDigitalError.userCancelled())
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
      
      let hostingController = UIHostingController(rootView: livenessView)
      self.navigationController?.pushViewController(hostingController, animated: true)
    }
  }
  
  private func presentSuccess() async throws {
    return try await withCheckedThrowingContinuation { continuation in
      let successView = DeviceAssociationSuccessView() {
        continuation.resume()
      }
      let hostingController = UIHostingController(rootView: successView)
      navigationController?.setViewControllers([hostingController], animated: true)
    }
  }
}
