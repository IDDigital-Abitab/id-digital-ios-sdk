import Foundation
import XCTest
import UIKit
import IDDigitalSDK

final class IDDigitalSDKTests: XCTestCase {
  func testGetDeviceAssociationBeforeInitializeThrows() async {
    do {
      _ = try await IDDigitalSDK.shared.getDeviceAssociation()
      XCTFail("Expected notInitialized before initialize()")
    } catch IDDigitalError.notInitialized {
      // Expected contract.
    } catch {
      XCTFail("Expected notInitialized, got \(error)")
    }
  }

  func testParseAuthenticationLink() {
    let url = URL(string: "iddigital://authenticate?transactionId=transaction-123")!

    XCTAssertEqual(
      IDDigitalSDK.parseAuthenticationLink(url: url),
      "transaction-123"
    )
  }

  func testParseAuthenticationLinkWithoutTransactionReturnsNil() {
    let url = URL(string: "iddigital://authenticate?code=oidc-code")!

    XCTAssertNil(IDDigitalSDK.parseAuthenticationLink(url: url))
  }
}

// This function is intentionally not executed. Compiling the test target verifies that the
// supported integration surface remains accessible to an external Swift module.
private func compilePublicContract(
  sdk: IDDigitalSDK,
  viewController: UIViewController,
  environment: IDDigitalSDKEnvironment,
  challengeType: ChallengeType,
  document: Document,
  association: DeviceAssociation,
  error: IDDigitalError
) async throws {
  _ = environment
  _ = document
  _ = association
  _ = error

  try await sdk.initialize(apiKey: "api-key", environment: environment)
  _ = try await sdk.associate(from: viewController, transactionId: "transaction-id")
  _ = try await sdk.associateViaQrScan(from: viewController)
  _ = try await sdk.validateViaQrScan(from: viewController, type: challengeType)
  _ = await sdk.isAssociated()
  _ = try await sdk.getDeviceAssociation()
  await sdk.removeAssociation()
  let validationSessionId = try await sdk.createValidationSession(
    from: viewController,
    type: challengeType
  )
  _ = try await sdk.completeTransaction(
    transactionId: "transaction-id",
    validationSessionId: validationSessionId
  )
  await sdk.startActiveTransactionPolling { _ in }
  await sdk.stopActiveTransactionPolling()
}
