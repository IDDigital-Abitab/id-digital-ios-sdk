import FactoryKit

final class CompleteDeviceAssociationUseCase {
  @Injected(\.validationSessionRepository) private var repository
  func execute(id: String) async throws -> DeviceAssociation {
    return try await repository.completeDeviceAssociation(id: id)
  }
}
