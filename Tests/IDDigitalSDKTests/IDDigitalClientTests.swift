import UIKit
import XCTest
@testable import IDDigitalSDK

final class IDDigitalClientTests: SDKTestCase {
  func testGetDeviceAssociationBeforeInitializeThrows() async {
    // Given la SDK no fue inicializada
    // When el integrador consulta la asociación
    let error = await requireError {
      _ = try await IDDigitalClient.shared.getDeviceAssociation()
    }

    // Then la SDK pide initialize() primero
    guard case .notInitialized = error else {
      return XCTFail("Se esperaba notInitialized y llegó \(String(describing: error))")
    }
  }

  func testFailedInitializeLeavesTheSDKUninitialized() async {
    // Given Amplify no puede arrancar
    // When initialize falla
    let error = await requireError {
      try await initializeSDK(bootstrap: FailingBootstrap())
    }

    // Then la SDK sigue sin inicializar y una operación posterior lo informa
    guard case .invalidApiKey = error else {
      return XCTFail("Se esperaba invalidApiKey y llegó \(String(describing: error))")
    }
    let followUp = await requireError {
      _ = try await IDDigitalClient.shared.getDeviceAssociation()
    }
    guard case .notInitialized = followUp else {
      return XCTFail("Se esperaba notInitialized y llegó \(String(describing: followUp))")
    }
  }

  func testSecondInitializeDoesNotBootstrapAgain() async throws {
    // Given la SDK ya arrancó una vez
    let bootstrap = RecordingBootstrap()
    try await initializeSDK(bootstrap: bootstrap)

    // When el integrador vuelve a llamar initialize()
    try await IDDigitalClient.shared.initialize(apiKey: "otra-key", environment: .production)

    // Then Amplify no se configura de nuevo
    let calls = await bootstrap.calls
    XCTAssertEqual(calls, 1)
  }

  func testIsAssociatedReflectsLocalStorage() async {
    // Given un dispositivo sin asociación
    let before = await IDDigitalClient.shared.isAssociated()

    // When la asociación queda guardada en el dispositivo
    await associations.save(association: Fixtures.association())
    let after = await IDDigitalClient.shared.isAssociated()

    // Then el estado pasa de no asociado a asociado
    XCTAssertFalse(before)
    XCTAssertTrue(after)
  }

  func testGetDeviceAssociationAfterInitializeReturnsStoredAssociation() async throws {
    // Given la SDK está inicializada y el dispositivo tiene una asociación con idToken
    try await initializeSDK()
    await associations.save(association: Fixtures.association(idToken: "header.payload.sig"))

    // When el integrador consulta la asociación
    let association = try await IDDigitalClient.shared.getDeviceAssociation()

    // Then recibe el token de asociación y el idToken
    XCTAssertEqual(association?.token, "assoc-token")
    XCTAssertEqual(association?.idToken, "header.payload.sig")
    XCTAssertEqual(association?.document.number, "12345672")
  }

  func testValidateViaQrScanWithoutAssociationThrows() async throws {
    // Given la SDK está inicializada y el dispositivo no está asociado
    try await initializeSDK()

    // When el integrador intenta validar escaneando un QR
    let rejected = await validateViaQrScanRejectsUnassociatedDevice()

    // Then la SDK rechaza la operación antes de presentar la cámara
    XCTAssertTrue(rejected)
  }

  func testRemoveAssociationClearsLocalDataWhenBackendSucceeds() async throws {
    // Given un dispositivo asociado y un backend que acepta la baja
    await associations.save(association: Fixtures.association())
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 200, json: "{}")

    // When el integrador desasocia el dispositivo
    await IDDigitalClient.shared.removeAssociation()

    // Then la SDK borra la asociación local y la preferencia de PIN
    let stored = await associations.get()
    let pin = await pins.pin
    let biometricEnabled = await pins.biometricEnabled
    XCTAssertNil(stored)
    XCTAssertEqual(pin, "")
    XCTAssertFalse(biometricEnabled)
    XCTAssertTrue(StubHTTP.shared.lastRequest?.url?.absoluteString.contains("associations/") == true)
  }

  func testRemoveAssociationClearsLocalDataWhenBackendFails() async {
    // Given un dispositivo asociado y un backend caído
    await associations.save(association: Fixtures.association())
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 500, json: #"{"code":"internal-error"}"#)

    // When el integrador desasocia el dispositivo
    await IDDigitalClient.shared.removeAssociation()

    // Then la SDK igual limpia los datos locales
    let stored = await associations.get()
    let pin = await pins.pin
    XCTAssertNil(stored)
    XCTAssertEqual(pin, "")
  }

  func testCompleteTransactionReturnsFinishUrl() async throws {
    // Given una sesión de validación ya resuelta
    try await initializeSDK()
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 200, json: #"{"data":{"finishUrl":"https://rp.example/done"}}"#)

    // When el integrador completa la transacción OIDC
    let finishUrl = try await IDDigitalClient.shared.completeTransaction(
      transactionId: "tx-1",
      validationSessionId: "session-1"
    )

    // Then la SDK devuelve la URL final y envía los identificadores
    XCTAssertEqual(finishUrl, "https://rp.example/done")
    XCTAssertEqual(StubHTTP.shared.lastRequest?.value(forHTTPHeaderField: "x-api-key"), "test-api-key")
    XCTAssertTrue(StubHTTP.shared.lastBody.contains("tx-1"))
    XCTAssertTrue(StubHTTP.shared.lastBody.contains("session-1"))
  }

  func testCompleteTransactionSurfacesTransactionNotFound() async throws {
    // Given el backend no conoce la transacción
    try await initializeSDK()
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 404, json: #"{"code":"transaction-not-found"}"#)

    // When el integrador intenta completarla
    let error = await requireError {
      _ = try await IDDigitalClient.shared.completeTransaction(
        transactionId: "missing",
        validationSessionId: "session-1"
      )
    }

    // Then la SDK informa que la transacción no existe
    guard case .transactionNotFound = error else {
      return XCTFail("Se esperaba transactionNotFound y llegó \(String(describing: error))")
    }
  }

  func testCompleteTransactionRequiresInitialize() async {
    // Given la SDK no fue inicializada
    // When el integrador intenta completar una transacción
    let error = await requireError {
      _ = try await IDDigitalClient.shared.completeTransaction(
        transactionId: "tx-1",
        validationSessionId: "session-1"
      )
    }

    // Then la SDK pide initialize() primero
    guard case .notInitialized = error else {
      return XCTFail("Se esperaba notInitialized y llegó \(String(describing: error))")
    }
  }

  func testPollingReportsTheOldestPendingTransaction() async throws {
    // Given un dispositivo asociado y una transacción pendiente
    await associations.save(association: Fixtures.association())
    installStubbedNetwork()
    StubHTTP.shared.stub(
      status: 200,
      json: #"{"data":{"transactions":[{"id":"tx-9"},{"id":"tx-10"}]}}"#
    )
    let found = expectation(description: "transacción pendiente")
    let box = TransactionBox(found)

    // When arranca el polling de transacciones activas
    await IDDigitalClient.shared.startActiveTransactionPolling(intervalMs: 20) { id in
      box.report(id)
    }

    // Then informa la más antigua y se detiene
    await fulfillment(of: [found], timeout: 3)
    XCTAssertEqual(box.id, "tx-9")
    await IDDigitalClient.shared.stopActiveTransactionPolling()
  }

  func testPollingWaitsSilentlyUntilTheDeviceIsAssociated() async {
    // Given un dispositivo todavía no asociado
    installStubbedNetwork()
    let found = expectation(description: "no debe informar transacción")
    found.isInverted = true

    // When arranca el polling
    await IDDigitalClient.shared.startActiveTransactionPolling(intervalMs: 30) { _ in
      found.fulfill()
    }

    // Then no consulta como error y no dispara el callback
    await fulfillment(of: [found], timeout: 0.4)
    XCTAssertNil(StubHTTP.shared.lastRequest)
    await IDDigitalClient.shared.stopActiveTransactionPolling()
  }
}

@MainActor
private func validateViaQrScanRejectsUnassociatedDevice() async -> Bool {
  let controller = UIViewController()
  do {
    _ = try await IDDigitalClient.shared.validateViaQrScan(from: controller, type: .pin)
    return false
  } catch IDDigitalError.deviceNotAssociated {
    return true
  } catch {
    return false
  }
}

private final class TransactionBox: @unchecked Sendable {
  let expectation: XCTestExpectation
  var id: String?

  init(_ expectation: XCTestExpectation) {
    self.expectation = expectation
  }

  func report(_ id: String) {
    self.id = id
    expectation.fulfill()
  }
}
