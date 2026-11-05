import XCTest
@testable import IDDigitalSDK

final class ConfigServiceTests: SDKTestCase {
  func testGetConfigurationDecodesCognitoData() async throws {
    // Given el backend entrega la configuración de Cognito
    installStubbedNetwork()
    StubHTTP.shared.stub(
      status: 200,
      json: """
      {"data":{"cognitoAppClientId":"client-1","cognitoUserPoolId":"user-pool","cognitoIdentityPoolId":"identity-pool","region":"us-east-1"}}
      """
    )

    // When la SDK inicializa su configuración
    let config = try await ConfigService().getConfiguration()

    // Then quedan los datos que después usa Amplify
    XCTAssertEqual(config.cognitoAppClientId, "client-1")
    XCTAssertEqual(config.cognitoUserPoolId, "user-pool")
    XCTAssertEqual(config.cognitoIdentityPoolId, "identity-pool")
    XCTAssertEqual(config.region, "us-east-1")
    XCTAssertTrue(StubHTTP.shared.lastRequest?.url?.absoluteString.hasSuffix("/initialize/") == true)
  }

  func testGetConfigurationAllowsMissingAppClientId() async throws {
    // Given el backend no manda AppClientId
    installStubbedNetwork()
    StubHTTP.shared.stub(
      status: 200,
      json: """
      {"data":{"cognitoAppClientId":null,"cognitoUserPoolId":"user-pool","cognitoIdentityPoolId":"identity-pool","region":"us-east-1"}}
      """
    )

    // When la SDK lee la configuración
    let config = try await ConfigService().getConfiguration()

    // Then el cliente de Cognito queda vacío y el resto se conserva
    XCTAssertNil(config.cognitoAppClientId)
    XCTAssertEqual(config.cognitoIdentityPoolId, "identity-pool")
  }
}
