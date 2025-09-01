import FactoryKit

final class ValidatePinChallengeUseCase {
  @Injected(\.pinRepository) private var repository
  func execute(challengeId: String, pin: String) async throws {
    try await repository.validateChallenge(challengeId: challengeId, pin: pin)
  }
}
