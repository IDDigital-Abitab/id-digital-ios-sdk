import Foundation
import UIKit
import FactoryKit


public final actor IDDigitalSDK {
  public static let shared = IDDigitalSDK()
  
  private var isInitialized = false
  
  private init() {}
  
  public func initialize(
    apiKey: String,
    environment: IDDigitalSDKEnvironment,
    cognitoAppClientIdOverride: String? = nil
  ) async throws {
    guard !isInitialized else {
      print("IDDigitalSDK has already been initialized.")
      return
    }
    Container.shared.apiKey.register { apiKey }
    Container.shared.environment.register { environment }
    Container.shared.cognitoAppClientIdOverride.register { cognitoAppClientIdOverride }
    try await AmplifyInitializer.initialize()
    self.isInitialized = true
    print("IDDigitalSDK initialized successfully.")
  }
  
  private func ensureInitialized() throws {
    guard isInitialized else {
      throw IDDigitalError.notInitialized
    }
  }
  
  
  /// Checks if a user with the given document can be associated with the device.
  public func canAssociate(document: Document) async throws -> Bool {
    try ensureInitialized()
    do {
      let useCase = Container.shared.checkCanAssociateUseCase()
      return try await useCase.execute(document: document)
    } catch {
      throw error.toIDDigitalError()
    }
  }
  
  
  /// Completes device association and returns the ID token JWT, or an empty string if the backend did not include one.
  @MainActor
  public func associate(from presentingViewController: UIViewController, document: Document) async throws -> String {
    try await ensureInitialized()
    
    let coordinator = DeviceAssociationCoordinator(
      presentingViewController: presentingViewController,
      document: document
    )
    
    let finalToken = try await coordinator.start()
    return finalToken
  }
  
  public func isAssociated() async -> Bool {
    let storage = Container.shared.deviceAssociationStorage()
    let association = await storage.get()
    return association != nil
  }
  
  public func getDeviceAssociation() async throws -> DeviceAssociation? {
    try ensureInitialized()
    let storage = Container.shared.deviceAssociationStorage()
    return await storage.get()
  }
  
  public func removeAssociation() async {
    do {
      let useCase = Container.shared.removeAssociationUseCase()
      try await useCase.execute()
    } catch {
      print("Failed to remove association from backend: \(error.localizedDescription)")
    }
    let storage = Container.shared.deviceAssociationStorage()
    await storage.remove()
    
    let pinManager = Container.shared.pinDataStoreManager()
    await pinManager.savePinAndBiometricPreference(pin: "", isEnabled: false)
  }
  
  @MainActor
  public func createValidationSession(from presentingViewController: UIViewController, type: ChallengeType) async throws {
    try await ensureInitialized()
    
    let coordinator = ValidationCoordinator(
      presentingViewController: presentingViewController,
      challengeType: type
    )
    
    try await coordinator.start()
  }
  
  /// Sends the OIDC **ID token** (JWT from `DeviceAssociation.idToken`) to Keycloak as `sdk_token`.
  public func sendToKeycloak(
    tabId: String,
    sessionCode: String,
    clientId: String,
    realm: String,
    sdkToken: String
  ) async throws -> String {
    try ensureInitialized()
    do {
      let keycloakService = Container.shared.keycloakService()
      return try await keycloakService.sendAuthenticationData(
        tabId: tabId,
        sessionCode: sessionCode,
        clientId: clientId,
        realm: realm,
        sdkToken: sdkToken
      )
    } catch {
      throw error.toIDDigitalError()
    }
  }
}
