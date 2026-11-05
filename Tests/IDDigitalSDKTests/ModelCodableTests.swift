import XCTest
@testable import IDDigitalSDK

final class ModelCodableTests: XCTestCase {
  func testDeviceAssociationRoundTripsWithTheKeychainEncoder() throws {
    // Given una asociación con idToken, como la que se guarda en el llavero
    let association = Fixtures.association(idToken: "header.payload.sig")

    // When se serializa y se vuelve a leer con el encoder por defecto
    let data = try JSONEncoder().encode(association)
    let decoded = try JSONDecoder().decode(DeviceAssociation.self, from: data)

    // Then el idToken y el documento se conservan
    XCTAssertEqual(decoded.token, "assoc-token")
    XCTAssertEqual(decoded.idToken, "header.payload.sig")
    XCTAssertEqual(decoded.document.number, "12345672")
    XCTAssertEqual(decoded.document.type, "ci")
    XCTAssertEqual(decoded.document.country, "UY")
    XCTAssertEqual(decoded.createdAt, "2026-01-01T00:00:00Z")
  }

  func testDeviceAssociationDecodesSnakeCaseFromTheNetwork() throws {
    // Given el JSON snake_case que entiende el cliente de red
    let json = """
    {"token":"assoc-token","document":{"number":"12345672","type":"ci","country":"UY"},"created_at":"2026-01-01T00:00:00Z","id_token":"header.payload.sig"}
    """

    // When se decodifica con la estrategia de la SDK
    let decoded = try Self.networkDecoder().decode(DeviceAssociation.self, from: Data(json.utf8))

    // Then el idToken queda disponible
    XCTAssertEqual(decoded.idToken, "header.payload.sig")
    XCTAssertEqual(decoded.createdAt, "2026-01-01T00:00:00Z")
  }

  func testDeviceAssociationAllowsNullIdToken() throws {
    // Given una asociación sin idToken
    let json = """
    {"token":"assoc-token","document":{"number":"1","type":"ci","country":"UY"},"createdAt":"2026-01-01T00:00:00Z","idToken":null}
    """

    // When se decodifica
    let decoded = try JSONDecoder().decode(DeviceAssociation.self, from: Data(json.utf8))

    // Then el token de asociación existe y el idToken no
    XCTAssertEqual(decoded.token, "assoc-token")
    XCTAssertNil(decoded.idToken)
  }

  func testValidationSessionDecodesChallenges() throws {
    // Given una sesión con un desafío de PIN
    let json = """
    {"id":"session-1","status":"pending","challenges":[{"id":"ch-1","type":"pin","status":"pending","expiration_date":"2026-01-02T00:00:00Z"}],"type":"validation","created_at":"2026-01-01T00:00:00Z","expiration_date":"2026-01-03T00:00:00Z","payload":{"source":"sdk"}}
    """

    // When se decodifica con la estrategia de la red
    let session = try Self.networkDecoder().decode(ValidationSession.self, from: Data(json.utf8))

    // Then el desafío y los campos opcionales están presentes
    XCTAssertEqual(session.id, "session-1")
    XCTAssertEqual(session.challenges.first?.type, .pin)
    XCTAssertEqual(session.challenges.first?.expirationDate, "2026-01-02T00:00:00Z")
    XCTAssertEqual(session.createdAt, "2026-01-01T00:00:00Z")
    XCTAssertEqual(session.payload?["source"], "sdk")
  }

  func testChallengeTypeRoundTrips() throws {
    // Given los dos desafíos que presenta la SDK
    // When se serializan
    let encoder = JSONEncoder()
    let pin = try encoder.encode(ChallengeType.pin)
    let liveness = try encoder.encode(ChallengeType.liveness)

    // Then salen los raw values del contrato
    XCTAssertEqual(String(data: pin, encoding: .utf8), "\"pin\"")
    XCTAssertEqual(String(data: liveness, encoding: .utf8), "\"liveness\"")
  }

  func testPendingTransactionsDecode() throws {
    // Given el listado del canal de polling
    let json = #"{"transactions":[{"id":"tx-9"}]}"#

    // When se decodifica
    let response = try JSONDecoder().decode(PendingTransactionsResponse.self, from: Data(json.utf8))

    // Then queda el id de la transacción más antigua
    XCTAssertEqual(response.transactions.map(\.id), ["tx-9"])
  }

  func testApiResponseUnwrapsData() throws {
    // Given el envelope de la API
    let json = #"{"data":{"value":"ok"}}"#

    // When se decodifica
    let response = try JSONDecoder().decode(ApiResponse<Value>.self, from: Data(json.utf8))

    // Then el dato útil está en data
    XCTAssertEqual(response.data.value, "ok")
  }

  func testConfigDataDecodesSnakeCase() throws {
    // Given la configuración de Cognito en snake_case
    let json = """
    {"cognito_app_client_id":"client-1","cognito_user_pool_id":"user-pool","cognito_identity_pool_id":"identity-pool","region":"us-east-1"}
    """

    // When se decodifica con la estrategia de la red
    let config = try Self.networkDecoder().decode(ConfigData.self, from: Data(json.utf8))

    // Then los ids de Cognito quedan disponibles para Amplify
    XCTAssertEqual(config.cognitoAppClientId, "client-1")
    XCTAssertEqual(config.cognitoUserPoolId, "user-pool")
    XCTAssertEqual(config.region, "us-east-1")
  }

  private static func networkDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }
}

private struct Value: Decodable {
  let value: String
}
