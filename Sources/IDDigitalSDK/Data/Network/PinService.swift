import Foundation
import FactoryKit

final class PinService {
  @Injected(\.networkClient) private var networkClient
  
  func executeChallenge(challengeId: String) async throws -> Date? {
    struct EmptyBody: Encodable {}
    struct ResponseData: Decodable {
      let pinLastUpdated: Date?
    }
    
    let response: ResponseData = try await networkClient.post(path: "challenges/\(challengeId)/execute/", body: EmptyBody())
    return response.pinLastUpdated
  }
  
  func validateChallenge(challengeId: String, pin: String) async throws {
    struct RequestBody: Encodable { let pin: String }
    try await networkClient.postAndExpectEmptyResponse(path: "challenges/\(challengeId)/validate/", body: RequestBody(pin: pin))
    
  }
}
