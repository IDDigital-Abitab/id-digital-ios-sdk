import FactoryKit

final class CreateValidationSessionUseCase {
  @Injected(\.validationSessionRepository) private var repository
  func execute(type: ChallengeType) async throws -> ValidationSession {
    return try await repository.createValidationSession(type: type)
  }
}
