import Foundation
import FactoryKit

final class LivenessService {
  @Injected(\.networkClient) private var networkClient
  
  func executeChallenge(challengeId: String) async throws -> String {
    struct ResponseData: Decodable {
      let sessionId: String
    }
    
    let response: ResponseData = try await networkClient.post(path: "challenges/\(challengeId)/execute/", body: EmptyBody())
    return response.sessionId
  }
  
  func validateChallenge(challengeId: String)  async throws {
    try await networkClient.postAndExpectEmptyResponse(path: "challenges/\(challengeId)/validate/", body: EmptyBody())
  }
}
