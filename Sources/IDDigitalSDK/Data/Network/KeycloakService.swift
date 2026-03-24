import Foundation
import FactoryKit

final class KeycloakService {
  @Injected(\.environment) private var environment
  
  private var keycloakBaseUrl: String {
    switch environment {
    case .staging:
      return "https://bqm-keycloak-dev.alabamasolutions.com"
    case .production:
      return "https://bqm-keycloak.alabamasolutions.com"
    }
  }
  
  private func buildKeycloakUrl(realm: String, path: String) -> String {
    return "\(keycloakBaseUrl)/realms/\(realm)/\(path)"
  }
  
  func sendAuthenticationData(
    tabId: String,
    sessionCode: String,
    clientId: String,
    realm: String,
    sdkToken: String
  ) async throws -> String {
    let urlString = buildKeycloakUrl(realm: realm, path: "protocol/openid-connect/token")
    guard let url = URL(string: urlString) else {
      throw IDDigitalError.unknown(cause: nil)
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    
    // Build form body
    var components = URLComponents()
    components.queryItems = [
      URLQueryItem(name: "grant_type", value: "password"),
      URLQueryItem(name: "session_code", value: sessionCode),
      URLQueryItem(name: "tab_id", value: tabId),
      URLQueryItem(name: "client_id", value: clientId),
      URLQueryItem(name: "sdk_token", value: sdkToken)
    ]
    
    // URLComponents creates query string, but we need form-encoded body
    let formString = components.queryItems?.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&") ?? ""
    request.httpBody = formString.data(using: .utf8)
    
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      
      guard let httpResponse = response as? HTTPURLResponse else {
        throw IDDigitalError.unexpectedResponse(statusCode: -1, responseBody: nil)
      }
      
      guard (200...299).contains(httpResponse.statusCode) else {
        let responseBody = String(data: data, encoding: .utf8)
        switch httpResponse.statusCode {
        case 400, 404:
          throw IDDigitalError.badResponse(statusCode: httpResponse.statusCode, responseBody: responseBody)
        case 500...599:
          throw IDDigitalError.serviceUnavailable(statusCode: httpResponse.statusCode, responseBody: responseBody)
        default:
          throw IDDigitalError.unexpectedResponse(statusCode: httpResponse.statusCode, responseBody: responseBody)
        }
      }
      
      guard let responseString = String(data: data, encoding: .utf8) else {
        throw IDDigitalError.badResponse(statusCode: httpResponse.statusCode, responseBody: nil)
      }
      
      return responseString
    } catch {
      if error is IDDigitalError {
        throw error
      }
      throw error.toIDDigitalError()
    }
  }
}
