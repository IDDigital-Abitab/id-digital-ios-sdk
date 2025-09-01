import FactoryKit
import Foundation

final class ValidateLivenessChallengeUseCase {
  @Injected(\.livenessRepository) private var repository
  func execute(challengeId: String) async throws {
    try await repository.validateChallenge(challengeId: challengeId)
  }
}
