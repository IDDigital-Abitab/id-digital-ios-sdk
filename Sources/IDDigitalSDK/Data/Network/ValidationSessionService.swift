import FactoryKit

final class ValidationSessionService {
  @Injected(\.networkClient) private var networkClient
  
  func checkCanAssociate(document: Document) async throws -> Bool {
    struct RequestBody: Encodable {
      let document_number: String
      let document_type: String
      let document_country: String
    }
    
    let body = RequestBody(
      document_number: document.number,
      document_type: document.type ?? "ci",
      document_country: document.country ?? "UY"
    )
    
    struct ResponseData: Decodable {
      let canAssociate: Bool
    }
    
    let response: ResponseData = try await networkClient.post(path: "can-associate/", body: body)
    
    return response.canAssociate
  }
  
  func createDeviceAssociation(document: Document) async throws -> ValidationSession {
    struct RequestBody: Encodable {
      let documentNumber: String
      let documentType: String
      let documentCountry: String
    }
    
    let body = RequestBody(
      documentNumber: document.number,
      documentType: document.type ?? "ci",
      documentCountry: document.country ?? "UY"
    )
    
    let response: ValidationSession = try await networkClient.post(path: "associations/", body: body)
    return response
  }
  
  func completeDeviceAssociation(id: String) async throws -> DeviceAssociation {
    struct EmptyBody: Encodable {}
    let response: DeviceAssociation = try await networkClient.post(path: "associations/\(id)/", body: EmptyBody())
    return response
  }
  
  func removeAssociation() async throws {
    try await networkClient.delete(path: "associations/")
  }
  
  func createValidationSession(type: ChallengeType) async throws -> ValidationSession {
    struct RequestBody: Encodable {
      let challengesTypes: [String]
    }
    let body = RequestBody(challengesTypes: [type.rawValue])
    
    let response: ValidationSession = try await networkClient.post(path: "validations/", body: body)
    return response
  }
}
