import XCTest
@testable import IDDigitalSDK

final class AuthenticationLinkTests: XCTestCase {
  func testParseAuthenticationLinkReturnsTransactionId() {
    // Given a deep link de autenticación recibido en el mismo dispositivo
    let url = URL(string: "iddigital://authenticate?transactionId=transaction-123")!

    // When la app le pide a la SDK el identificador
    let transactionId = IDDigitalClient.parseAuthenticationLink(url: url)

    // Then el transactionId queda disponible para associate o completeTransaction
    XCTAssertEqual(transactionId, "transaction-123")
  }

  func testParseAuthenticationLinkWithoutTransactionReturnsNil() {
    // Given un redirect que no trae una transacción de ID Digital
    let url = URL(string: "iddigital://authenticate?code=oidc-code")!

    // When la app le pide a la SDK el identificador
    let transactionId = IDDigitalClient.parseAuthenticationLink(url: url)

    // Then la SDK lo ignora
    XCTAssertNil(transactionId)
  }
}
