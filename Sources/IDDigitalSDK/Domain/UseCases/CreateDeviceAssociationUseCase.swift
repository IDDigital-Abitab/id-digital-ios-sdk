import FactoryKit

final class CreateDeviceAssociationUseCase {
  @Injected(\.validationSessionRepository) private var repository
  
  func execute(transactionId: String) async throws -> ValidationSession {
    return try await repository.createDeviceAssociation(transactionId: transactionId)
  }
}
