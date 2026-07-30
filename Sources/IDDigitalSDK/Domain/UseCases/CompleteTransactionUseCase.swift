import FactoryKit

final class CompleteTransactionUseCase {
  @Injected(\.validationSessionRepository) private var repository
  func execute(transactionId: String, validationSessionId: String) async throws -> String? {
    try await repository.completeTransaction(transactionId: transactionId, validationSessionId: validationSessionId)
  }
}
