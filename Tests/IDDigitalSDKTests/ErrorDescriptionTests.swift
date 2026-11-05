import XCTest
@testable import IDDigitalSDK

final class ErrorDescriptionTests: XCTestCase {
  func testEachErrorDescribesItself() {
    // Given el catálogo de errores que puede ver el integrador
    let samples: [(IDDigitalError, String)] = [
      (.noInternetConnection(), "internet"),
      (.timeout(), "timed out"),
      (.unknownHost(), "host"),
      (.serviceUnavailable(statusCode: 503, responseBody: nil), "503"),
      (.badResponse(statusCode: 400, responseBody: nil), "400"),
      (.unexpectedResponse(statusCode: 418, responseBody: nil), "418"),
      (.notInitialized, "initialize"),
      (.invalidApiKey(reason: "vacía"), "vacía"),
      (.invalidDocument(reason: "ilegible"), "ilegible"),
      (.tooManyAttempts, "attempts"),
      (.deviceNotAssociated, "not associated"),
      (.invalidChallengeId(reason: "ch-1"), "ch-1"),
      (.invalidPin(reason: "Incorrect PIN"), "Incorrect PIN"),
      (.challengeValidationFailed(), "validation"),
      (.transactionNotFound, "transaction"),
      (.validationSessionNotFound, "session"),
      (.sessionHasUncompletedChallenges, "challenges"),
      (.forbidden, "Forbidden"),
      (.cameraPermissionDenied(), "Camera"),
      (.userCancelled(), "cancelled"),
      (.unknown(), "unknown"),
    ]

    // When se pide la descripción de cada uno
    // Then cada caso tiene un texto propio
    for (error, fragment) in samples {
      let description = error.errorDescription ?? ""
      XCTAssertTrue(
        description.localizedCaseInsensitiveContains(fragment),
        "\(error) no contiene \(fragment): \(description)"
      )
    }
  }

  func testURLErrorsMapToSDKErrors() {
    // Given fallos de URLSession
    let offline = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
    let timeout = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
    let host = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost)
    let other = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse)
    let unrelated = NSError(domain: "test", code: 1)

    // When la SDK los traduce
    // Then cada uno cae en el caso correspondiente
    guard case .noInternetConnection = offline.toIDDigitalError() else {
      return XCTFail("offline")
    }
    guard case .timeout = timeout.toIDDigitalError() else {
      return XCTFail("timeout")
    }
    guard case .unknownHost = host.toIDDigitalError() else {
      return XCTFail("host")
    }
    guard case .unknown = other.toIDDigitalError() else {
      return XCTFail("other url")
    }
    guard case .unknown = unrelated.toIDDigitalError() else {
      return XCTFail("unrelated")
    }
  }

  func testSDKErrorPassesThroughTranslation() {
    // Given un IDDigitalError ya clasificado
    let original = IDDigitalError.notInitialized

    // When se vuelve a traducir
    let translated = original.toIDDigitalError()

    // Then se conserva
    guard case .notInitialized = translated else {
      return XCTFail("\(translated)")
    }
  }
}
