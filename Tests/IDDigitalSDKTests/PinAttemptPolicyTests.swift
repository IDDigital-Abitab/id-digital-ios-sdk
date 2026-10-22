import XCTest
@testable import IDDigitalSDK

final class PinAttemptPolicyTests: XCTestCase {
  func testFirstTwoInvalidPinsStayOnTheScreen() {
    let first = PinAttemptPolicy.action(for: IDDigitalError.invalidPin(reason: "Incorrect PIN"), invalidAttempts: 0)
    guard case .showWrongPin = first.0 else {
      return XCTFail("Expected retry, got \(first.0)")
    }
    XCTAssertEqual(first.1, 1)

    let second = PinAttemptPolicy.action(for: IDDigitalError.invalidPin(reason: "Incorrect PIN"), invalidAttempts: first.1)
    guard case .showWrongPin = second.0 else {
      return XCTFail("Expected retry, got \(second.0)")
    }
    XCTAssertEqual(second.1, 2)
  }

  func testThirdInvalidPinClosesWithoutCountingFurther() {
    let decision = PinAttemptPolicy.action(
      for: IDDigitalError.invalidPin(reason: "Incorrect PIN"),
      invalidAttempts: 2
    )
    guard case .close(let error) = decision.0 else {
      return XCTFail("Expected close, got \(decision.0)")
    }
    guard case .challengeValidationFailed = error else {
      return XCTFail("Expected challengeValidationFailed, got \(error)")
    }
    XCTAssertEqual(decision.1, 3)
  }

  func testTooManyAttemptsClosesImmediately() {
    let decision = PinAttemptPolicy.action(for: IDDigitalError.tooManyAttempts, invalidAttempts: 1)
    guard case .close(let error) = decision.0 else {
      return XCTFail("Expected close, got \(decision.0)")
    }
    guard case .tooManyAttempts = error else {
      return XCTFail("Expected tooManyAttempts, got \(error)")
    }
    XCTAssertEqual(decision.1, 1)
  }

  func testFinishedChallengeDoesNotLookLikeAWrongPin() {
    let decision = PinAttemptPolicy.action(
      for: IDDigitalError.badResponse(statusCode: 400, responseBody: "Challenge cannot be validated."),
      invalidAttempts: 0
    )
    guard case .close(let error) = decision.0 else {
      return XCTFail("Expected close, got \(decision.0)")
    }
    guard case .badResponse(let statusCode, _, _) = error else {
      return XCTFail("Expected badResponse, got \(error)")
    }
    XCTAssertEqual(statusCode, 400)
    XCTAssertEqual(decision.1, 0)
  }

  func testNetworkAndServerErrorsDoNotCount() {
    let network = PinAttemptPolicy.action(for: IDDigitalError.noInternetConnection(), invalidAttempts: 1)
    guard case .stay = network.0 else {
      return XCTFail("Expected stay, got \(network.0)")
    }
    XCTAssertEqual(network.1, 1)

    let server = PinAttemptPolicy.action(
      for: IDDigitalError.serviceUnavailable(statusCode: 503, responseBody: nil),
      invalidAttempts: 1
    )
    guard case .stay = server.0 else {
      return XCTFail("Expected stay, got \(server.0)")
    }
    XCTAssertEqual(server.1, 1)

    let otherStatus = PinAttemptPolicy.action(
      for: IDDigitalError.badResponse(statusCode: 422, responseBody: nil),
      invalidAttempts: 1
    )
    guard case .stay = otherStatus.0 else {
      return XCTFail("Expected stay, got \(otherStatus.0)")
    }
    XCTAssertEqual(otherStatus.1, 1)
  }
}
