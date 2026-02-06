import Foundation
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

  // MARK: - Challenge execute/validate (for when backend supports them; not exposed in public API yet)

  func executeChallenge(challengeId: String, data: Record) async throws {
    let (responseData, response) = try await networkClient.postWithJSONBody(
      path: "challenges/\(challengeId)/execute/",
      body: data
    )
    guard (200...299).contains(response.statusCode) else {
      let responseBody = String(data: responseData, encoding: .utf8)
      switch response.statusCode {
      case 400, 404: throw IDDigitalError.badResponse(statusCode: response.statusCode, responseBody: responseBody)
      case 500...599: throw IDDigitalError.serviceUnavailable(statusCode: response.statusCode, responseBody: responseBody)
      default: throw IDDigitalError.unexpectedResponse(statusCode: response.statusCode, responseBody: responseBody)
      }
    }
  }

  func validateChallenge(challengeId: String, data: Record) async throws -> Bool {
    let (responseData, response) = try await networkClient.postWithJSONBody(
      path: "challenges/\(challengeId)/validate/",
      body: data
    )
    if (200...299).contains(response.statusCode) {
      return true
    }
    let responseBody = String(data: responseData, encoding: .utf8)
    if response.statusCode == 400 || response.statusCode == 404 {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      if let errorResponse = try? decoder.decode(ErrorResponse.self, from: responseData) {
        if errorResponse.code == "invalid-pin" {
          return false
        }
        if errorResponse.code == "too-many-attempts" {
          throw IDDigitalError.tooManyAttempts
        }
      }
      throw IDDigitalError.badResponse(statusCode: response.statusCode, responseBody: responseBody)
    }
    if (500...599).contains(response.statusCode) {
      throw IDDigitalError.serviceUnavailable(statusCode: response.statusCode, responseBody: responseBody)
    }
    throw IDDigitalError.unexpectedResponse(statusCode: response.statusCode, responseBody: responseBody)
  }
}
