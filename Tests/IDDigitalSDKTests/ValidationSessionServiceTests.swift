import XCTest
@testable import IDDigitalSDK

final class ValidationSessionServiceTests: SDKTestCase {
  func testCreateDeviceAssociationDecodesTheSession() async throws {
    // Given una asociación pendiente con un desafío de PIN
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 200, json: Fixtures.sessionJSON())

    // When la SDK inicia la asociación
    let session = try await CreateDeviceAssociationUseCase().execute(transactionId: "tx-1")

    // Then la sesión y el desafío quedan disponibles, y el id viaja en el cuerpo
    XCTAssertEqual(session.id, "session-1")
    XCTAssertEqual(session.challenges.first?.type, .pin)
    XCTAssertTrue(StubHTTP.shared.lastRequest?.url?.absoluteString.hasSuffix("/associations/") == true)
    XCTAssertTrue(StubHTTP.shared.lastBody.contains("\"transaction_id\":\"tx-1\""))
  }

  func testCreateDeviceAssociationReportsTransactionNotFound() async {
    // Given el backend no conoce la transacción
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 404, json: #"{"code":"transaction-not-found"}"#)

    // When la SDK inicia la asociación
    let error = await requireError {
      _ = try await CreateDeviceAssociationUseCase().execute(transactionId: "missing")
    }

    // Then informa que la transacción no existe
    guard case .transactionNotFound = error else {
      return XCTFail("Se esperaba transactionNotFound y llegó \(String(describing: error))")
    }
  }

  func testCreateDeviceAssociationReportsServiceUnavailable() async {
    // Given el backend falla con 500
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 500, json: #"{"code":"internal-error"}"#)

    // When la SDK inicia la asociación
    let error = await requireError {
      _ = try await CreateDeviceAssociationUseCase().execute(transactionId: "tx-1")
    }

    // Then informa servicio no disponible
    guard case .serviceUnavailable(let statusCode, _, _) = error else {
      return XCTFail("Se esperaba serviceUnavailable y llegó \(String(describing: error))")
    }
    XCTAssertEqual(statusCode, 500)
  }

  func testCompleteDeviceAssociationReturnsIdToken() async throws {
    // Given el backend emite un idToken para la asociación
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 200, json: Fixtures.associationJSON(idToken: "header.payload.sig"))

    // When la asociación se completa
    let association = try await CompleteDeviceAssociationUseCase().execute(id: "session-1")

    // Then la SDK devuelve el idToken y el documento
    XCTAssertEqual(association.idToken, "header.payload.sig")
    XCTAssertEqual(association.document.number, "12345672")
    XCTAssertEqual(association.document.type, "ci")
    XCTAssertTrue(StubHTTP.shared.lastRequest?.url?.absoluteString.hasSuffix("/associations/session-1/") == true)
  }

  func testCompleteDeviceAssociationAllowsMissingIdToken() async throws {
    // Given el backend no incluye idToken
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 200, json: Fixtures.associationJSON(idToken: nil))

    // When la asociación se completa
    let association = try await CompleteDeviceAssociationUseCase().execute(id: "session-1")

    // Then la asociación sigue siendo válida
    XCTAssertNil(association.idToken)
    XCTAssertEqual(association.token, "assoc-token")
  }

  func testCreateValidationSessionSendsTheChallengeType() async throws {
    // Given un dispositivo que va a resolver liveness
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 200, json: Fixtures.sessionJSON(challengeType: "liveness"))

    // When la SDK crea la sesión de validación
    let session = try await CreateValidationSessionUseCase().execute(type: .liveness)

    // Then pide solo ese desafío
    XCTAssertEqual(session.challenges.first?.type, .liveness)
    XCTAssertTrue(StubHTTP.shared.lastRequest?.url?.absoluteString.hasSuffix("/validations/") == true)
    XCTAssertTrue(StubHTTP.shared.lastBody.contains("liveness"))
  }

  func testRemoveAssociationCallsTheBackend() async throws {
    // Given el backend acepta la baja
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 200, json: "{}")

    // When la SDK desasocia
    try await RemoveAssociationUseCase().execute()

    // Then el DELETE pega a associations/
    XCTAssertEqual(StubHTTP.shared.lastRequest?.httpMethod, "DELETE")
    XCTAssertTrue(StubHTTP.shared.lastRequest?.url?.absoluteString.hasSuffix("/associations/") == true)
  }

  func testPendingTransactionsReturnsTheList() async throws {
    // Given el backend tiene dos transacciones pendientes
    installStubbedNetwork()
    StubHTTP.shared.stub(
      status: 200,
      json: #"{"data":{"transactions":[{"id":"tx-9"},{"id":"tx-10"}]}}"#
    )

    // When la SDK consulta el canal de polling
    let pending = try await GetPendingTransactionsUseCase().execute()

    // Then devuelve ambas, en orden
    XCTAssertEqual(pending.map(\.id), ["tx-9", "tx-10"])
    XCTAssertTrue(StubHTTP.shared.lastRequest?.url?.absoluteString.hasSuffix("/transactions/pending/") == true)
  }

  func testCompleteTransactionReturnsNilWhenFinishUrlIsMissing() async throws {
    // Given el backend acepta la transacción pero no arma una URL final
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 200, json: #"{"data":{}}"#)

    // When la SDK la completa
    let finishUrl = try await CompleteTransactionUseCase().execute(
      transactionId: "tx-1",
      validationSessionId: "session-1"
    )

    // Then el integrador sigue por el polling del navegador
    XCTAssertNil(finishUrl)
    XCTAssertTrue(StubHTTP.shared.lastRequest?.url?.absoluteString.hasSuffix("/complete-transaction/") == true)
    XCTAssertTrue(StubHTTP.shared.lastBody.contains("\"transaction_id\":\"tx-1\""))
    XCTAssertTrue(StubHTTP.shared.lastBody.contains("\"validation_session_id\":\"session-1\""))
  }

  func testCompleteTransactionReportsValidationSessionNotFound() async {
    await assertCompleteTransaction(code: "validation-session-not-found", status: 404) { error in
      if case .validationSessionNotFound = error { return true }
      return false
    }
  }

  func testCompleteTransactionReportsUncompletedChallenges() async {
    await assertCompleteTransaction(code: "session-has-uncompleted-challenges", status: 400) { error in
      if case .sessionHasUncompletedChallenges = error { return true }
      return false
    }
  }

  func testCompleteTransactionReportsForbidden() async {
    await assertCompleteTransaction(code: "forbidden", status: 403) { error in
      if case .forbidden = error { return true }
      return false
    }
  }

  func testCompleteTransactionReportsBadResponse() async {
    // Given un 422 sin código conocido
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 422, json: #"{"code":"other"}"#)

    // When la SDK completa la transacción
    let error = await completeTransactionError()

    // Then la clasifica como respuesta inválida
    guard case .badResponse(let statusCode, _, _) = error else {
      return XCTFail("Se esperaba badResponse y llegó \(String(describing: error))")
    }
    XCTAssertEqual(statusCode, 422)
  }

  func testCompleteTransactionReportsServiceUnavailable() async {
    // Given el backend responde 500
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 500, json: #"{"code":"internal-error"}"#)

    // When la SDK completa la transacción
    let error = await completeTransactionError()

    // Then informa servicio no disponible
    guard case .serviceUnavailable(let statusCode, _, _) = error else {
      return XCTFail("Se esperaba serviceUnavailable y llegó \(String(describing: error))")
    }
    XCTAssertEqual(statusCode, 500)
  }

  func testCompleteTransactionReportsUnexpectedResponse() async {
    // Given un estado HTTP no mapeado
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 418, json: #"{"code":"other"}"#)

    // When la SDK completa la transacción
    let error = await completeTransactionError()

    // Then informa una respuesta no contemplada
    guard case .unexpectedResponse(let statusCode, _, _) = error else {
      return XCTFail("Se esperaba unexpectedResponse y llegó \(String(describing: error))")
    }
    XCTAssertEqual(statusCode, 418)
  }

  private func assertCompleteTransaction(
    code: String,
    status: Int,
    file: StaticString = #filePath,
    line: UInt = #line,
    matches: (IDDigitalError) -> Bool
  ) async {
    // Given el backend rechaza el cierre de la transacción
    installStubbedNetwork()
    StubHTTP.shared.stub(status: status, json: #"{"code":"\#(code)"}"#)

    // When la SDK intenta completarla
    let error = await completeTransactionError(file: file, line: line)

    // Then clasifica el código de negocio
    guard let error, matches(error) else {
      return XCTFail("Código \(code) produjo \(String(describing: error))", file: file, line: line)
    }
  }

  private func completeTransactionError(
    file: StaticString = #filePath,
    line: UInt = #line
  ) async -> IDDigitalError? {
    await requireError({
      _ = try await CompleteTransactionUseCase().execute(
        transactionId: "tx-1",
        validationSessionId: "session-1"
      )
    }, file: file, line: line)
  }
}
