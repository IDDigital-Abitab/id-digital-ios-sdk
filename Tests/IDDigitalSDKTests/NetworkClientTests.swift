import FactoryKit
import XCTest
@testable import IDDigitalSDK

final class NetworkClientTests: SDKTestCase {
  private struct Body: Encodable {
    let transactionId: String
  }

  func testStagingRequestSendsApiKeyAndFingerprint() async throws {
    // Given la SDK apunta a staging y no hay asociación local
    StubHTTP.shared.stub(status: 200, json: #"{"data":{"value":"ok"}}"#)
    let client = installStubbedNetwork()

    // When consulta un recurso
    let probe: Probe = try await client.get(path: "probe/")

    // Then pega al host de staging con la API key y el fingerprint, sin bearer
    XCTAssertEqual(probe.value, "ok")
    let request = try XCTUnwrap(StubHTTP.shared.lastRequest)
    XCTAssertEqual(request.url?.host, "auth.identificaciondigital.com.uy")
    XCTAssertTrue(request.url?.absoluteString.hasSuffix("/api/v2/sdk/probe/") == true)
    XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-api-key")
    XCTAssertEqual(request.value(forHTTPHeaderField: "x-device-fingerprint"), "fingerprint-test")
    XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
  }

  func testProductionRequestUsesProductionHost() async throws {
    // Given la SDK apunta a producción
    Container.shared.environment.register { .production }
    StubHTTP.shared.stub(status: 200, json: #"{"data":{"value":"ok"}}"#)
    let client = installStubbedNetwork()

    // When consulta un recurso
    let _: Probe = try await client.get(path: "probe/")

    // Then pega al host productivo
    XCTAssertEqual(
      StubHTTP.shared.lastRequest?.url?.host,
      "auth.identidaddigital.com.uy"
    )
  }

  func testCustomBaseUrlOverridesTheEnvironmentHost() async throws {
    // Given un backend de desarrollo con barra final
    Container.shared.customBaseUrl.register { "https://backend.test/api/v2/sdk/" }
    StubHTTP.shared.stub(status: 200, json: #"{"data":{"value":"ok"}}"#)
    let client = installStubbedNetwork()

    // When consulta la configuración
    let _: Probe = try await client.get(path: "initialize/")

    // Then usa esa base, sin duplicar la barra
    XCTAssertEqual(
      StubHTTP.shared.lastRequest?.url?.absoluteString,
      "https://backend.test/api/v2/sdk/initialize/"
    )
  }

  func testAssociatedDeviceSendsBearerToken() async throws {
    // Given una asociación guardada en el dispositivo
    await associations.save(association: Fixtures.association())
    StubHTTP.shared.stub(status: 200, json: #"{"data":{"value":"ok"}}"#)
    let client = installStubbedNetwork()

    // When consulta un recurso
    let _: Probe = try await client.get(path: "probe/")

    // Then autoriza con el token de la asociación
    XCTAssertEqual(
      StubHTTP.shared.lastRequest?.value(forHTTPHeaderField: "Authorization"),
      "Bearer assoc-token"
    )
  }

  func testPostEncodesCamelCaseFieldsAsSnakeCase() async throws {
    // Given un cuerpo con identificador de transacción
    StubHTTP.shared.stub(status: 200, json: #"{"data":{"value":"ok"}}"#)
    let client = installStubbedNetwork()

    // When la SDK hace el POST
    let _: Probe = try await client.post(path: "associations/", body: Body(transactionId: "tx-1"))

    // Then el JSON sale en snake_case
    XCTAssertTrue(StubHTTP.shared.lastBody.contains("\"transaction_id\":\"tx-1\""))
    XCTAssertEqual(StubHTTP.shared.lastRequest?.httpMethod, "POST")
  }

  func testInvalidJSONBecomesBadResponse() async {
    // Given una respuesta 200 que no respeta el envelope
    StubHTTP.shared.stub(status: 200, json: #"{"unexpected":true}"#)
    let client = installStubbedNetwork()

    // When la SDK intenta decodificarla
    let error = await requireError {
      let _: Probe = try await client.get(path: "probe/")
    }

    // Then informa una respuesta inválida
    guard case .badResponse(let statusCode, _, _) = error else {
      return XCTFail("Se esperaba badResponse y llegó \(String(describing: error))")
    }
    XCTAssertEqual(statusCode, -1)
  }

  func testInvalidPin() async {
    // Given / When el backend responde invalid-pin
    // Then el error es de PIN inválido
    await assertStatusError(code: "invalid-pin", status: 400) { error in
      if case .invalidPin = error { return true }
      return false
    }
  }

  func testTooManyAttempts() async {
    // Given / When el backend responde too-many-attempts
    // Then el usuario agotó los intentos
    await assertStatusError(code: "too-many-attempts", status: 400) { error in
      if case .tooManyAttempts = error { return true }
      return false
    }
  }

  func testInvalidDeviceAssociationToken() async {
    // Given / When el backend ya no reconoce el token de asociación
    // Then la SDK trata al dispositivo como no asociado
    await assertStatusError(code: "invalid-device-association-token", status: 401) { error in
      if case .deviceNotAssociated = error { return true }
      return false
    }
  }

  func testInvalidIdentityDocumentUsesBackendMessage() async {
    // Given el backend rechaza el documento
    StubHTTP.shared.stub(
      status: 422,
      json: #"{"code":"invalid-identity-document","message":"documento ilegible"}"#
    )
    let client = installStubbedNetwork()

    // When la SDK recibe el rechazo
    let error = await postExpectingFailure(client)

    // Then conserva el mensaje del backend
    guard case .invalidDocument(let reason, _) = error else {
      return XCTFail("Se esperaba invalidDocument y llegó \(String(describing: error))")
    }
    XCTAssertEqual(reason, "documento ilegible")
  }

  func testTransactionNotFound() async {
    await assertStatusError(code: "transaction-not-found", status: 404) { error in
      if case .transactionNotFound = error { return true }
      return false
    }
  }

  func testUnknownClientErrorBecomesBadResponse() async {
    // Given un 404 sin código conocido
    StubHTTP.shared.stub(status: 404, json: #"{"code":"other"}"#)
    let client = installStubbedNetwork()

    // When la SDK recibe la respuesta
    let error = await postExpectingFailure(client)

    // Then la clasifica como respuesta inválida
    guard case .badResponse(let statusCode, _, _) = error else {
      return XCTFail("Se esperaba badResponse y llegó \(String(describing: error))")
    }
    XCTAssertEqual(statusCode, 404)
  }

  func testServerErrorBecomesServiceUnavailable() async {
    // Given el backend responde 500
    StubHTTP.shared.stub(status: 503, json: #"{"code":"internal-error"}"#)
    let client = installStubbedNetwork()

    // When la SDK recibe la respuesta
    let error = await postExpectingFailure(client)

    // Then informa servicio no disponible
    guard case .serviceUnavailable(let statusCode, _, _) = error else {
      return XCTFail("Se esperaba serviceUnavailable y llegó \(String(describing: error))")
    }
    XCTAssertEqual(statusCode, 503)
  }

  func testUnexpectedStatusBecomesUnexpectedResponse() async {
    // Given un estado HTTP que la SDK no tiene mapeado
    StubHTTP.shared.stub(status: 401, json: #"{"code":"other"}"#)
    let client = installStubbedNetwork()

    // When la SDK recibe la respuesta
    let error = await postExpectingFailure(client)

    // Then informa una respuesta no contemplada
    guard case .unexpectedResponse(let statusCode, _, _) = error else {
      return XCTFail("Se esperaba unexpectedResponse y llegó \(String(describing: error))")
    }
    XCTAssertEqual(statusCode, 401)
  }

  func testOfflineErrorBecomesNoInternetConnection() async {
    await assertURLError(.notConnectedToInternet) { error in
      if case .noInternetConnection = error { return true }
      return false
    }
  }

  func testTimeoutError() async {
    await assertURLError(.timedOut) { error in
      if case .timeout = error { return true }
      return false
    }
  }

  func testUnknownHostError() async {
    await assertURLError(.cannotFindHost) { error in
      if case .unknownHost = error { return true }
      return false
    }
  }

  func testOtherURLErrorBecomesUnknown() async {
    await assertURLError(.networkConnectionLost) { error in
      if case .unknown = error { return true }
      return false
    }
  }

  func testInvalidBaseUrlBecomesUnknown() async {
    // Given una URL base que no se puede armar
    Container.shared.customBaseUrl.register { "https://exa mple.test" }
    let client = installStubbedNetwork()

    // When la SDK intenta llamar
    let error = await requireError {
      let _: Probe = try await client.get(path: "probe/")
    }

    // Then informa un error no clasificado y no llega a salir la request
    guard case .unknown = error else {
      return XCTFail("Se esperaba unknown y llegó \(String(describing: error))")
    }
    XCTAssertNil(StubHTTP.shared.lastRequest)
  }

  func testDeleteReachesTheAssociationsPath() async throws {
    // Given el backend acepta la baja
    StubHTTP.shared.stub(status: 200, json: "{}")
    let client = installStubbedNetwork()

    // When la SDK borra la asociación
    try await client.delete(path: "associations/")

    // Then el método y el path son los del contrato
    XCTAssertEqual(StubHTTP.shared.lastRequest?.httpMethod, "DELETE")
    XCTAssertTrue(StubHTTP.shared.lastRequest?.url?.absoluteString.hasSuffix("/associations/") == true)
  }

  func testEmptyPostIgnoresTheResponseBody() async throws {
    // Given un desafío que responde vacío
    StubHTTP.shared.stub(status: 200, json: "")
    let client = installStubbedNetwork()

    // When la SDK valida sin esperar un data
    try await client.postAndExpectEmptyResponse(path: "challenges/ch-1/validate/", body: Body(transactionId: "ignored"))

    // Then la llamada se considera exitosa
    XCTAssertEqual(StubHTTP.shared.lastRequest?.httpMethod, "POST")
  }

  private func assertStatusError(
    code: String,
    status: Int,
    file: StaticString = #filePath,
    line: UInt = #line,
    matches: (IDDigitalError) -> Bool
  ) async {
    // Given el backend responde con un código de negocio
    StubHTTP.shared.stub(status: status, json: #"{"code":"\#(code)"}"#)
    let client = installStubbedNetwork()

    // When la SDK recibe la respuesta
    let error = await postExpectingFailure(client, file: file, line: line)

    // Then la clasifica según ese código
    guard let error, matches(error) else {
      return XCTFail("Código \(code) produjo \(String(describing: error))", file: file, line: line)
    }
  }

  private func assertURLError(
    _ urlError: URLError.Code,
    file: StaticString = #filePath,
    line: UInt = #line,
    matches: (IDDigitalError) -> Bool
  ) async {
    // Given la request falla en la capa de red
    StubHTTP.shared.fail(URLError(urlError))
    let client = installStubbedNetwork()

    // When la SDK intenta llamar
    let error = await postExpectingFailure(client, file: file, line: line)

    // Then traduce el fallo a un error de la SDK
    guard let error, matches(error) else {
      return XCTFail("\(urlError) produjo \(String(describing: error))", file: file, line: line)
    }
  }

  private func postExpectingFailure(
    _ client: DefaultNetworkClient,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async -> IDDigitalError? {
    await requireError({
      try await client.postAndExpectEmptyResponse(path: "probe/", body: Body(transactionId: "tx-1"))
    }, file: file, line: line)
  }
}

private struct Probe: Decodable {
  let value: String
}
