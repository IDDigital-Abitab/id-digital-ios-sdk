import FactoryKit

final class CreateDeviceAssociationUseCase {
  @Injected(\.validationSessionRepository) private var repository
  
  func execute(document: Document) async throws -> ValidationSession {
    return try await repository.createDeviceAssociation(document: document)
  }
}
