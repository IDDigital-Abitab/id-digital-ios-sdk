import Foundation
import FactoryKit

final class ValidationSessionService {
  @Injected(\.networkClient) private var networkClient
  
  /// - Parameter transactionId: The pending `TransactionOIDC` id (raw or signed token, see
  ///   `IDDigitalSDK.associate(from:transactionId:)`). The backend resolves the citizen from
  ///   this transaction instead of requiring a document.
  func createDeviceAssociation(transactionId: String) async throws -> ValidationSession {
    struct RequestBody: Encodable {
      let transactionId: String
    }
    
    let body = RequestBody(transactionId: transactionId)
    
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

  /// Completes a pending OIDC transaction (cross-device / same-device web bridge flow)
  /// using an already-completed `ValidationSession`. Backend:
  /// `POST /api/v2/sdk/complete-transaction/`.
  ///
  /// - Returns: the `finishUrl` the backend generated for this transaction, or nil if it
  ///   couldn't generate one (the web bridge's own polling is always the fallback in that
  ///   case).
  func completeTransaction(transactionId: String, validationSessionId: String) async throws -> String? {
    let (responseData, response) = try await networkClient.postWithJSONBody(
      path: "complete-transaction/",
      body: [
        "transaction_id": transactionId,
        "validation_session_id": validationSessionId
      ]
    )
    if (200...299).contains(response.statusCode) {
      struct ResponseData: Decodable {
        let finishUrl: String?
      }
      let apiResponse = try? JSONDecoder().decode(ApiResponse<ResponseData>.self, from: responseData)
      return apiResponse?.data.finishUrl
    }
    let responseBody = String(data: responseData, encoding: .utf8)
    if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: responseData) {
      switch errorResponse.code {
      case "transaction-not-found": throw IDDigitalError.transactionNotFound
      case "validation-session-not-found": throw IDDigitalError.validationSessionNotFound
      case "session-has-uncompleted-challenges": throw IDDigitalError.sessionHasUncompletedChallenges
      case "forbidden": throw IDDigitalError.forbidden
      default: break
      }
    }
    switch response.statusCode {
    case 400, 401, 403, 404, 422: throw IDDigitalError.badResponse(statusCode: response.statusCode, responseBody: responseBody)
    case 500...599: throw IDDigitalError.serviceUnavailable(statusCode: response.statusCode, responseBody: responseBody)
    default: throw IDDigitalError.unexpectedResponse(statusCode: response.statusCode, responseBody: responseBody)
    }
  }

  /// Lists pending OIDC transactions for the citizen behind the current
  /// DeviceAssociation (bearer token added by `NetworkClient.makeRequestRaw`).
  /// Used by `IDDigitalSDK.startActiveTransactionPolling` -
  /// .docs/sdk/cliente/09-polling-transaccion-activa.md.
  func getPendingTransactions() async throws -> [PendingTransaction] {
    let response: PendingTransactionsResponse = try await networkClient.get(path: "transactions/pending/")
    return response.transactions
  }

}
