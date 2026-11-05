import FactoryKit
import Foundation
import XCTest
@testable import IDDigitalSDK

actor InMemoryAssociationStore: DeviceAssociationStoring {
  private var association: DeviceAssociation?

  func save(association: DeviceAssociation) async {
    self.association = association
  }

  func get() async -> DeviceAssociation? {
    association
  }

  func remove() async {
    association = nil
  }
}

actor MemoryPinStore: PinDataStoreManaging {
  private(set) var pin: String?
  private(set) var biometricEnabled = false

  func savePinAndBiometricPreference(pin: String, isEnabled: Bool) async {
    self.pin = pin
    self.biometricEnabled = isEnabled
  }

  func isBiometricPinEnabled() async -> Bool { biometricEnabled }

  func getDecryptedPin() async -> String? { pin }

  func saveLastBiometricUsage() async {}

  func getLastBiometricUsage() async -> Date? { nil }

  func clearAll() async {
    pin = nil
    biometricEnabled = false
  }
}

struct FixedFingerprint: DeviceIdentifierProviding {
  func getDeviceFingerprint() async -> String { "fingerprint-test" }
}

struct SuccessfulBootstrap: SDKBootstrapping {
  func bootstrap() async throws {}
}

struct FailingBootstrap: SDKBootstrapping {
  func bootstrap() async throws {
    throw IDDigitalError.invalidApiKey(reason: "rejected")
  }
}

actor RecordingBootstrap: SDKBootstrapping {
  private(set) var calls = 0

  func bootstrap() async throws {
    calls += 1
  }
}

enum Fixtures {
  static func document() -> Document {
    Document(number: "12345672", type: "ci", country: "UY")
  }

  static func association(idToken: String? = "header.payload.sig") -> DeviceAssociation {
    DeviceAssociation(
      token: "assoc-token",
      document: document(),
      createdAt: "2026-01-01T00:00:00Z",
      idToken: idToken
    )
  }

  static func sessionJSON(id: String = "session-1", challengeType: String = "pin") -> String {
    """
    {"data":{"id":"\(id)","status":"pending","challenges":[{"id":"ch-1","type":"\(challengeType)","status":"pending","expirationDate":"2026-01-02T00:00:00Z"}]}}
    """
  }

  static func associationJSON(idToken: String? = "header.payload.sig") -> String {
    let tokenField = idToken.map { #""idToken":"\#($0)""# } ?? #""idToken":null"#
    return """
    {"data":{"token":"assoc-token","document":{"number":"12345672","type":"ci","country":"UY"},"createdAt":"2026-01-01T00:00:00Z",\(tokenField)}}
    """
  }
}

class SDKTestCase: XCTestCase {
  var associations: InMemoryAssociationStore!
  var pins: MemoryPinStore!

  override func setUp() async throws {
    try await super.setUp()
    await resetContainer()
  }

  override func tearDown() async throws {
    await IDDigitalClient.shared.stopActiveTransactionPolling()
    StubHTTP.shared.reset()
    Container.shared.manager.reset()
    await IDDigitalClient.shared.resetForTesting()
    try await super.tearDown()
  }

  func resetContainer() async {
    await IDDigitalClient.shared.stopActiveTransactionPolling()
    Container.shared.manager.reset()
    StubHTTP.shared.reset()
    await IDDigitalClient.shared.resetForTesting()

    let associations = InMemoryAssociationStore()
    let pins = MemoryPinStore()
    self.associations = associations
    self.pins = pins
    Container.shared.deviceAssociationStorage.register { associations }
    Container.shared.pinDataStoreManager.register { pins }
    Container.shared.deviceIdentifierProvider.register { FixedFingerprint() }
    Container.shared.apiKey.register { "test-api-key" }
    Container.shared.environment.register { .staging }
    Container.shared.customBaseUrl.register { nil as String? }
  }

  @discardableResult
  func installStubbedNetwork() -> DefaultNetworkClient {
    Container.shared.networkClient.register { DefaultNetworkClient(urlSession: Self.stubSession()) }
    return DefaultNetworkClient(urlSession: Self.stubSession())
  }

  nonisolated private static func stubSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: configuration)
  }

  @discardableResult
  func initializeSDK(bootstrap: SDKBootstrapping = SuccessfulBootstrap()) async throws -> SDKBootstrapping {
    Container.shared.sdkBootstrap.register { bootstrap }
    try await IDDigitalClient.shared.initialize(apiKey: "test-api-key", environment: .staging)
    return bootstrap
  }

  func requireError(
    _ body: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async -> IDDigitalError? {
    do {
      try await body()
      XCTFail("Se esperaba un IDDigitalError", file: file, line: line)
      return nil
    } catch let error as IDDigitalError {
      return error
    } catch {
      XCTFail("Se esperaba IDDigitalError y llegó \(error)", file: file, line: line)
      return nil
    }
  }
}
