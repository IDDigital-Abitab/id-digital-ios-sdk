import Foundation
import FactoryKit

protocol LivenessRepository {
  func executeChallenge(challengeId: String) async throws -> String
  func validateChallenge(challengeId: String) async throws
}

class LivenessRepositoryImpl: LivenessRepository {
  @Injected(\.livenessService) private var service
  
  func executeChallenge(challengeId: String) async throws -> String {
    return try await service.executeChallenge(challengeId: challengeId)
  }
  
  func validateChallenge(challengeId: String) async throws {
    try await service.validateChallenge(challengeId: challengeId)
  }
}
