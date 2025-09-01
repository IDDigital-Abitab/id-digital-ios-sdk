import FactoryKit
import Foundation

final class ExecuteLivenessChallengeUseCase {
  @Injected(\.livenessRepository) private var repository
  func execute(challengeId: String) async throws -> String {
    return try await repository.executeChallenge(challengeId: challengeId)
  }
}
