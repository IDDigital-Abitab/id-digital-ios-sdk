import FactoryKit

final class GetPendingTransactionsUseCase {
  @Injected(\.validationSessionRepository) private var repository
  func execute() async throws -> [PendingTransaction] {
    try await repository.getPendingTransactions()
  }
}
