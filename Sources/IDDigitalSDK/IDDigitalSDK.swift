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
    baseUrl: String? = nil,
    cognitoAppClientIdOverride: String? = nil
  ) async throws {
    guard !isInitialized else {
      print("IDDigitalSDK has already been initialized.")
      return
    }
    Container.shared.apiKey.register { apiKey }
    Container.shared.environment.register { environment }
    Container.shared.customBaseUrl.register {
      guard let baseUrl else { return nil }
      let trimmed = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
    }
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

  /// Extracts the `transactionId` from a same-device deep link opened by the web bridge
  /// (`deep_link_scheme://...?transactionId=...`, see
  /// .docs/sdk/cliente/07-deep-link-same-device.md). Returns nil if `url` isn't a deep
  /// link of this kind, so callers can safely try this against every incoming URL their
  /// app receives.
  public static func parseAuthenticationLink(url: URL) -> String? {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?.first(where: { $0.name == "transactionId" })?.value
  }

  
  /// Completes device association.
  ///
  /// - Parameter transactionId: The pending `TransactionOIDC` id, received via push
  ///   notification (raw), a same-device deep link, or scanned from a QR (both as a signed
  ///   token, see ``parseAuthenticationLink(url:)``). The backend resolves the citizen from
  ///   this transaction — the app never needs to know the citizen's document.
  /// - Returns: the `idToken` JWT issued for this association (empty string if the backend
  ///   did not include one), and the id of the `ValidationSession` created to complete it —
  ///   pass the latter to ``completeTransaction(transactionId:validationSessionId:)`` to close
  ///   a pending web-bridge login triggered by this association, received via push
  ///   notification or via a same-device deep link (see ``parseAuthenticationLink(url:)``).
  @MainActor
  public func associate(from presentingViewController: UIViewController, transactionId: String) async throws -> (idToken: String, validationSessionId: String) {
    try await ensureInitialized()
    
    let coordinator = DeviceAssociationCoordinator(
      presentingViewController: presentingViewController,
      transactionId: transactionId
    )
    
    return try await coordinator.start()
  }
  
  /// QR cross-device registration/association (registro reducido), see
  /// .docs/sdk/cliente/08-qr-cross-device.md. Presents the SDK's own camera
  /// screen to scan a QR shown by the web bridge (SPA); the decoded text is
  /// an opaque signed token that is never parsed here — it's forwarded as-is
  /// to resolve the citizen and create the association, then again to
  /// ``completeTransaction(transactionId:validationSessionId:)`` once the
  /// same liveness/PIN challenge flow used by ``associate(from:transactionId:)``
  /// finishes. No identifying data needs to be supplied upfront: the citizen
  /// isn't known until the QR is scanned.
  ///
  /// Unlike the same-device deep link, this is always cross-device: the SDK
  /// itself never opens the resulting `finishUrl` (the SPA on the other
  /// device is the one polling and will redirect on its own). The return
  /// value is only for observability/analytics.
  @MainActor
  public func associateViaQrScan(from presentingViewController: UIViewController) async throws -> String? {
    try await ensureInitialized()

    let coordinator = QrAssociationCoordinator(
      presentingViewController: presentingViewController
    )

    return try await coordinator.start()
  }

  /// QR cross-device validation for an **already associated** device, see
  /// .docs/sdk/cliente/08-qr-cross-device.md. Symmetrical to
  /// ``associateViaQrScan(from:)``, but for the validation challenge
  /// flow (``createValidationSession(from:type:)``) instead of
  /// ``associate(from:transactionId:)`` - use this when ``isAssociated()`` is
  /// true, ``associateViaQrScan(from:)`` otherwise.
  ///
  /// Presents the SDK's own camera screen to scan a QR shown by the web
  /// bridge (SPA); the decoded text is an opaque signed token that is never
  /// parsed here, just forwarded as-is to
  /// ``completeTransaction(transactionId:validationSessionId:)`` once `type`
  /// finishes.
  ///
  /// - Parameter type: Which challenge (PIN or liveness) the citizen will
  ///   complete after scanning, same as ``createValidationSession(from:type:)``.
  @MainActor
  public func validateViaQrScan(from presentingViewController: UIViewController, type: ChallengeType) async throws -> String? {
    try await ensureInitialized()

    guard await isAssociated() else {
      throw IDDigitalError.deviceNotAssociated
    }

    let coordinator = QrValidationCoordinator(
      presentingViewController: presentingViewController,
      challengeType: type
    )

    return try await coordinator.start()
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
  
  /// - Returns: the id of the `ValidationSession` that was just completed. Pass it to
  ///   ``completeTransaction(transactionId:validationSessionId:)`` to close a pending
  ///   web-bridge login, received via push notification or via a same-device deep link
  ///   (see ``parseAuthenticationLink(url:)``).
  @MainActor
  public func createValidationSession(from presentingViewController: UIViewController, type: ChallengeType) async throws -> String {
    try await ensureInitialized()
    
    let coordinator = ValidationCoordinator(
      presentingViewController: presentingViewController,
      challengeType: type
    )
    
    do {
      return try await coordinator.start()
    } catch IDDigitalError.deviceNotAssociated {
      // isAssociated() said true (local storage had an association), but the backend
      // rejected the token (see NetworkClient.makeRequest). Clear it so a subsequent
      // attempt goes through associate() again instead of repeating this same failure.
      let storage = Container.shared.deviceAssociationStorage()
      await storage.remove()
      throw IDDigitalError.deviceNotAssociated
    }
  }
  
  /// Starts polling for a pending OIDC transaction as a redundant channel alongside
  /// push (see .docs/sdk/cliente/09-polling-transaccion-activa.md) - replicates the
  /// mechanism the default ID Digital app already uses to authenticate without
  /// depending on push. Only covers recurring login: if the device isn't associated
  /// yet (``isAssociated()`` false), this silently waits without erroring, since
  /// there's no bearer token to poll with until an association exists.
  ///
  /// Automatically pauses while the host app is backgrounded, and stops itself right
  /// after the first `onTransactionDetected` call to avoid re-triggering the same
  /// transaction on every tick while it's being resolved - call this again (e.g. once
  /// ``completeTransaction(transactionId:validationSessionId:)`` closes that
  /// transaction) to resume polling for a next one.
  ///
  /// - Parameters:
  ///   - intervalMs: Time between polls while in foreground. Defaults to 10 seconds,
  ///     same cadence as the default app.
  ///   - onTransactionDetected: Called with the oldest pending `transactionId` found.
  ///     Handle it exactly like a `type: "validation"` push (see
  ///     .docs/sdk/cliente/04-invocacion-sdk.md): ``createValidationSession(from:type:)``
  ///     + ``completeTransaction(transactionId:validationSessionId:)``.
  public func startActiveTransactionPolling(
    intervalMs: UInt64 = ActiveTransactionPoller.defaultIntervalMs,
    onTransactionDetected: @escaping @Sendable (String) -> Void
  ) async {
    let poller = Container.shared.activeTransactionPoller()
    await poller.start(intervalMs: intervalMs, onTransactionDetected: onTransactionDetected)
  }

  /// Stops the polling started by ``startActiveTransactionPolling(intervalMs:onTransactionDetected:)``, if any.
  public func stopActiveTransactionPolling() async {
    let poller = Container.shared.activeTransactionPoller()
    await poller.stop()
  }

  /// Completes a pending OIDC transaction (cross-device / same-device web bridge flow)
  /// using an already-completed `ValidationSession`. Backend:
  /// `POST /api/v2/sdk/complete-transaction/`.
  ///
  /// - Parameters:
  ///   - transactionId: The `TransactionOIDC` id, received via push notification or via
  ///     a same-device deep link (see ``parseAuthenticationLink(url:)``).
  ///   - validationSessionId: The id of a `ValidationSession` that already reached
  ///     `COMPLETED` status (e.g. via `createValidationSession`) for the same citizen.
  /// - Returns: the `finishUrl` the backend generated for this transaction, or nil if it
  ///   couldn't generate one (the web bridge's own polling is always the fallback in that
  ///   case). If not nil, same-device integrations should open it (e.g.
  ///   `UIApplication.shared.open(URL(string: finishUrl)!)`) instead of relying on the
  ///   browser tab (that may be backgrounded) to redirect on its own — see
  ///   .docs/sdk/cliente/07-deep-link-same-device.md.
  public func completeTransaction(transactionId: String, validationSessionId: String) async throws -> String? {
    try ensureInitialized()
    do {
      let useCase = Container.shared.completeTransactionUseCase()
      return try await useCase.execute(transactionId: transactionId, validationSessionId: validationSessionId)
    } catch {
      throw error.toIDDigitalError()
    }
  }

}
