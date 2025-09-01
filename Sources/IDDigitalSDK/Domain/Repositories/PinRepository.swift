import Foundation
import FactoryKit

protocol PinRepository {
  func executeChallenge(challengeId: String) async throws -> Date?
  func validateChallenge(challengeId: String, pin: String) async throws
}

class PinRepositoryImpl: PinRepository {
  @Injected(\.pinService) private var service
  
  func executeChallenge(challengeId: String) async throws -> Date? {
    return try await service.executeChallenge(challengeId: challengeId)
  }
  
  func validateChallenge(challengeId: String, pin: String) async throws {
    try await service.validateChallenge(challengeId: challengeId, pin: pin)
  }
}
