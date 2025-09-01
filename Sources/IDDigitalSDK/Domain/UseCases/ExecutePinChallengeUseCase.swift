import FactoryKit
import Foundation

final class ExecutePinChallengeUseCase {
  @Injected(\.pinRepository) private var repository
  func execute(challengeId: String) async throws -> Date? {
    return try await repository.executeChallenge(challengeId: challengeId)
  }
}
