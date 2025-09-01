import FactoryKit

protocol ValidationSessionRepository {
  func checkCanAssociate(document: Document) async throws -> Bool
  func createDeviceAssociation(document: Document) async throws -> ValidationSession
  func completeDeviceAssociation(id: String) async throws -> DeviceAssociation
  func removeAssociation() async throws
  func createValidationSession(type: ChallengeType) async throws -> ValidationSession
}

final class ValidationSessionRepositoryImpl: ValidationSessionRepository {
  @Injected(\.validationSessionService) private var service
  
  func checkCanAssociate(document: Document) async throws -> Bool {
    return try await service.checkCanAssociate(document: document)
  }
  
  func createDeviceAssociation(document: Document) async throws -> ValidationSession {
    return try await service.createDeviceAssociation(document: document)
  }
  
  func completeDeviceAssociation(id: String) async throws -> DeviceAssociation {
    return try await service.completeDeviceAssociation(id: id)
  }
  
  func removeAssociation() async throws {
    try await service.removeAssociation()
  }
  
  func createValidationSession(type: ChallengeType) async throws -> ValidationSession {
    return try await service.createValidationSession(type: type)
  }
}
