import FactoryKit

protocol ValidationSessionRepository {
  func createDeviceAssociation(transactionId: String) async throws -> ValidationSession
  func completeDeviceAssociation(id: String) async throws -> DeviceAssociation
  func removeAssociation() async throws
  func createValidationSession(type: ChallengeType) async throws -> ValidationSession
  func completeTransaction(transactionId: String, validationSessionId: String) async throws -> String?
  func getPendingTransactions() async throws -> [PendingTransaction]
}

final class ValidationSessionRepositoryImpl: ValidationSessionRepository {
  @Injected(\.validationSessionService) private var service
  
  func createDeviceAssociation(transactionId: String) async throws -> ValidationSession {
    return try await service.createDeviceAssociation(transactionId: transactionId)
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

  func completeTransaction(transactionId: String, validationSessionId: String) async throws -> String? {
    try await service.completeTransaction(transactionId: transactionId, validationSessionId: validationSessionId)
  }

  func getPendingTransactions() async throws -> [PendingTransaction] {
    try await service.getPendingTransactions()
  }
}
