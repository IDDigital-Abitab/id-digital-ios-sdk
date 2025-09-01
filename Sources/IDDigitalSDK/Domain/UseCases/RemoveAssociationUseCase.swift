import FactoryKit

final class RemoveAssociationUseCase {
  @Injected(\.validationSessionRepository) private var repository
  func execute() async throws {
    try await repository.removeAssociation()
  }
}
