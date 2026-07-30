import Foundation
import UIKit
import FactoryKit

/// Punto de entrada de ID Digital para aplicaciones iOS.
///
/// El Integrador inicializa la instancia compartida una vez al iniciar la aplicación.
/// Luego puede asociar dispositivos, resolver desafíos de autenticación y completar
/// transacciones OIDC.
public final actor IDDigitalSDK {
  /// Instancia compartida de la SDK.
  public static let shared = IDDigitalSDK()
  
  private var isInitialized = false
  
  private init() {}
  
  /// Inicializa la SDK y configura los servicios requeridos.
  ///
  /// Las invocaciones posteriores no repiten la inicialización.
  ///
  /// - Parameters:
  ///   - apiKey: Credencial de integración entregada por ID Digital.
  ///   - environment: Ambiente de ID Digital que utilizará la SDK.
  ///   - baseUrl: URL base alternativa reservada para desarrollo y pruebas.
  ///   - cognitoAppClientIdOverride: Identificador alternativo de Cognito reservado
  ///     para desarrollo y pruebas.
  /// - Throws: ``IDDigitalError`` si la configuración no puede completarse.
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

  /// Extrae el `transactionId` de un deep link de autenticación recibido en el mismo
  /// dispositivo.
  ///
  /// - Parameter url: URL recibida por la aplicación.
  /// - Returns: El identificador de transacción, o `nil` si la URL no contiene
  ///   `transactionId`.
  public static func parseAuthenticationLink(url: URL) -> String? {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?.first(where: { $0.name == "transactionId" })?.value
  }

  
  /// Asocia el dispositivo a partir de una transacción pendiente.
  ///
  /// La SDK presenta su interfaz de asociación y ejecuta los desafíos configurados por
  /// ID Digital.
  ///
  /// - Parameters:
  ///   - presentingViewController: Controlador desde el que se presenta el flujo.
  ///   - transactionId: Identificador recibido por push o extraído de un deep link con
  ///     ``parseAuthenticationLink(url:)``.
  /// - Returns: El ID Token emitido y el identificador de la sesión de validación
  ///   completada. El Integrador usa esa sesión con
  ///   ``completeTransaction(transactionId:validationSessionId:)``.
  /// - Throws: ``IDDigitalError`` si la asociación no puede completarse.
  @MainActor
  public func associate(from presentingViewController: UIViewController, transactionId: String) async throws -> (idToken: String, validationSessionId: String) {
    try await ensureInitialized()
    
    let coordinator = DeviceAssociationCoordinator(
      presentingViewController: presentingViewController,
      transactionId: transactionId
    )
    
    return try await coordinator.start()
  }
  
  /// Asocia el dispositivo escaneando el QR mostrado en otro dispositivo.
  ///
  /// La SDK presenta la cámara, procesa el token firmado y completa internamente la
  /// transacción después de resolver los desafíos de asociación. No requiere datos
  /// identificatorios antes del escaneo.
  ///
  /// - Parameter presentingViewController: Controlador desde el que se presenta el
  ///   escáner y el flujo de asociación.
  /// - Returns: La URL final informativa devuelta por el backend, o `nil`.
  /// - Throws: ``IDDigitalError`` si el QR o la asociación no pueden procesarse.
  @MainActor
  public func associateViaQrScan(from presentingViewController: UIViewController) async throws -> String? {
    try await ensureInitialized()

    let coordinator = QrAssociationCoordinator(
      presentingViewController: presentingViewController
    )

    return try await coordinator.start()
  }

  /// Valida una asociación existente escaneando el QR mostrado en otro dispositivo.
  ///
  /// Este método se utiliza cuando ``isAssociated()`` devuelve `true`. Para un
  /// dispositivo todavía no asociado, se utiliza ``associateViaQrScan(from:)``.
  ///
  /// - Parameters:
  ///   - presentingViewController: Controlador desde el que se presenta el flujo.
  ///   - type: Desafío de PIN o prueba de vida que resolverá el Usuario.
  /// - Returns: La URL final informativa devuelta por el backend, o `nil`.
  /// - Throws: ``IDDigitalError`` si no existe una asociación o la validación falla.
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

  /// Indica si el dispositivo conserva una asociación local activa.
  ///
  /// - Returns: `true` cuando existe una asociación almacenada.
  public func isAssociated() async -> Bool {
    let storage = Container.shared.deviceAssociationStorage()
    let association = await storage.get()
    return association != nil
  }
  
  /// Devuelve la asociación almacenada en el dispositivo.
  ///
  /// - Returns: La asociación activa, o `nil` si todavía no existe.
  /// - Throws: ``IDDigitalError/notInitialized`` si la SDK no fue inicializada.
  public func getDeviceAssociation() async throws -> DeviceAssociation? {
    try ensureInitialized()
    let storage = Container.shared.deviceAssociationStorage()
    return await storage.get()
  }
  
  /// Elimina la asociación del backend y limpia los datos locales del dispositivo.
  ///
  /// Si el backend no está disponible, la SDK elimina igualmente los datos locales.
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
  
  /// Presenta y completa un desafío de validación para un dispositivo asociado.
  ///
  /// - Parameters:
  ///   - presentingViewController: Controlador desde el que se presenta el desafío.
  ///   - type: Tipo de desafío que debe resolver el Usuario.
  /// - Returns: El identificador de la sesión completada. Usalo con
  ///   ``completeTransaction(transactionId:validationSessionId:)``.
  /// - Throws: ``IDDigitalError`` si el dispositivo no está asociado o el desafío falla.
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
  
  /// Inicia el polling de transacciones OIDC pendientes como canal redundante al push.
  ///
  /// El polling se pausa cuando la aplicación queda en segundo plano y se detiene
  /// después de informar la primera transacción. El Integrador lo invoca nuevamente
  /// después de resolverla para detectar una transacción posterior. Si el dispositivo
  /// no está asociado, espera silenciosamente hasta que exista una asociación.
  ///
  /// - Parameters:
  ///   - intervalMs: Intervalo entre consultas en milisegundos. El valor
  ///     predeterminado es 10 segundos.
  ///   - onTransactionDetected: Callback que recibe el `transactionId` pendiente más
  ///     antiguo.
  public func startActiveTransactionPolling(
    intervalMs: UInt64 = 10_000,
    onTransactionDetected: @escaping @Sendable (String) -> Void
  ) async {
    let poller = Container.shared.activeTransactionPoller()
    await poller.start(intervalMs: intervalMs, onTransactionDetected: onTransactionDetected)
  }

  /// Detiene el polling iniciado con
  /// ``startActiveTransactionPolling(intervalMs:onTransactionDetected:)``.
  public func stopActiveTransactionPolling() async {
    let poller = Container.shared.activeTransactionPoller()
    await poller.stop()
  }

  /// Completa una transacción OIDC pendiente usando una sesión de validación resuelta.
  ///
  /// - Parameters:
  ///   - transactionId: Identificador recibido por push o extraído mediante
  ///     ``parseAuthenticationLink(url:)``.
  ///   - validationSessionId: Identificador devuelto por ``associate(from:transactionId:)``
  ///     o ``createValidationSession(from:type:)``.
  /// - Returns: La URL final generada para la transacción, o `nil` si el navegador debe
  ///   continuar mediante polling.
  /// - Throws: ``IDDigitalError`` si la transacción no puede completarse.
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
