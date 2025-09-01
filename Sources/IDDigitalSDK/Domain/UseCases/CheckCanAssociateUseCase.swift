import FactoryKit

final class CheckCanAssociateUseCase {
  @Injected(\.validationSessionRepository) private var repository
  
  func execute(document: Document) async throws -> Bool {
    if document.number.count < 7 {
      throw IDDigitalError.invalidDocument(reason: "Number is too short.")
    }
    return try await repository.checkCanAssociate(document: document)
  }
}
