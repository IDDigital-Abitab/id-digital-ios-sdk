import XCTest
@testable import IDDigitalSDK

final class PinAndLivenessServiceTests: SDKTestCase {
  func testExecutePinChallengeDecodesLastUpdate() async throws {
    // Given el backend informa la última actualización del PIN
    installStubbedNetwork()
    StubHTTP.shared.stub(
      status: 200,
      json: #"{"data":{"pinLastUpdated":"2026-01-02T03:04:05.12345+00:00"}}"#
    )

    // When la SDK ejecuta el desafío
    let updated = try await ExecutePinChallengeUseCase().execute(challengeId: "ch-pin")

    // Then recupera la fecha y pega al execute del desafío
    let expected = try Self.pinDate("2026-01-02T03:04:05.12345+00:00")
    XCTAssertEqual(updated, expected)
    XCTAssertTrue(
      StubHTTP.shared.lastRequest?.url?.absoluteString.hasSuffix("/challenges/ch-pin/execute/") == true
    )
  }

  func testExecutePinChallengeAllowsMissingDate() async throws {
    // Given el backend no tiene fecha de PIN
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 200, json: #"{"data":{"pinLastUpdated":null}}"#)

    // When la SDK ejecuta el desafío
    let updated = try await ExecutePinChallengeUseCase().execute(challengeId: "ch-pin")

    // Then sigue sin fecha
    XCTAssertNil(updated)
  }

  func testValidatePinChallengeSendsThePin() async throws {
    // Given un PIN ingresado por el usuario
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 200, json: "{}")

    // When la SDK lo valida
    try await ValidatePinChallengeUseCase().execute(challengeId: "ch-pin", pin: "1234")

    // Then el PIN viaja al validate del desafío
    XCTAssertTrue(
      StubHTTP.shared.lastRequest?.url?.absoluteString.hasSuffix("/challenges/ch-pin/validate/") == true
    )
    XCTAssertTrue(StubHTTP.shared.lastBody.contains("\"pin\":\"1234\""))
  }

  func testExecuteLivenessChallengeReturnsSessionId() async throws {
    // Given el backend abre una sesión de prueba de vida
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 200, json: #"{"data":{"sessionId":"liveness-session"}}"#)

    // When la SDK ejecuta el desafío
    let sessionId = try await ExecuteLivenessChallengeUseCase().execute(challengeId: "ch-live")

    // Then devuelve el id de sesión de Amplify
    XCTAssertEqual(sessionId, "liveness-session")
    XCTAssertTrue(
      StubHTTP.shared.lastRequest?.url?.absoluteString.hasSuffix("/challenges/ch-live/execute/") == true
    )
  }

  func testValidateLivenessChallengeCompletes() async throws {
    // Given una prueba de vida ya capturada
    installStubbedNetwork()
    StubHTTP.shared.stub(status: 200, json: "{}")

    // When la SDK la valida
    try await ValidateLivenessChallengeUseCase().execute(challengeId: "ch-live")

    // Then pega al validate del desafío
    XCTAssertTrue(
      StubHTTP.shared.lastRequest?.url?.absoluteString.hasSuffix("/challenges/ch-live/validate/") == true
    )
  }

  private static func pinDate(_ value: String) throws -> Date {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSXXXXX"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return try XCTUnwrap(formatter.date(from: value))
  }
}
