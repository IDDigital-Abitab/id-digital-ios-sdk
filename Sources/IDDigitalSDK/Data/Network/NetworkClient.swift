import Foundation
import FactoryKit

struct EmptyBody: Codable {}

/// A helper struct to decode the specific error code from the backend on failure.
struct ErrorResponse: Decodable {
  let code: String?
}

protocol NetworkClient {
  func get<T: Decodable>(path: String) async throws -> T
  func post<T: Decodable>(path: String, body: some Encodable) async throws -> T
  func postAndExpectEmptyResponse(path: String, body: some Encodable) async throws
  func delete(path: String) async throws
}

final class DefaultNetworkClient: NetworkClient {
  @Injected(\.apiKey) private var apiKey
  @Injected(\.deviceIdentifierProvider) private var deviceIdentifierProvider
  @Injected(\.deviceAssociationStorage) private var deviceAssociationStorage
  
  private var baseUrl: String {
    switch environment {
    case .staging:
      return "https://auth.identificaciondigital.com.uy/api/v2/sdk"
    case .production:
      return "https://auth.identidaddigital.com.uy/api/v2/sdk"
    }
  }
  private let urlSession: URLSession
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  
  init(urlSession: URLSession = .shared) {
    self.urlSession = urlSession
    self.encoder = JSONEncoder()
    self.encoder.keyEncodingStrategy = .convertToSnakeCase
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSXXXXX"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    
    self.decoder = JSONDecoder()
    self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    self.decoder.dateDecodingStrategy = .formatted(dateFormatter)
  }
  
  func get<T: Decodable>(path: String) async throws -> T {
    let (data, _) = try await makeRequest(path: path, method: "GET", body: EmptyBody())
    
    do {
      let apiResponse = try decoder.decode(ApiResponse<T>.self, from: data)
      return apiResponse.data
    } catch {
      throw IDDigitalError.badResponse(statusCode: -1, responseBody: "JSON decoding failed: \(error.localizedDescription)")
    }
  }
  
  func post<T: Decodable>(path: String, body: some Encodable) async throws -> T {
    let (data, _) = try await makeRequest(path: path, method: "POST", body: body)
    
    do {
      let apiResponse = try decoder.decode(ApiResponse<T>.self, from: data)
      return apiResponse.data
    } catch {
      throw IDDigitalError.badResponse(statusCode: -1, responseBody: "JSON decoding failed: \(error.localizedDescription)")
    }
  }
  
  func postAndExpectEmptyResponse(path: String, body: some Encodable) async throws {
    _ = try await makeRequest(path: path, method: "POST", body: body)
  }
  
  func delete(path: String) async throws {
    _ = try await makeRequest(path: path, method: "DELETE", body: EmptyBody())
  }
  
  private func makeRequest(path: String, method: String, body: some Encodable) async throws -> (Data, HTTPURLResponse) {
    guard let url = URL(string: "\(baseUrl)/\(path)") else {
      throw IDDigitalError.unknown(cause: nil)
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
    
    if let apiKey = self.apiKey {
      request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    }
    
    let fingerprint = await deviceIdentifierProvider.getDeviceFingerprint()
    request.setValue(fingerprint, forHTTPHeaderField: "x-device-fingerprint")
    
    if let association = await deviceAssociationStorage.get() {
      request.setValue("Bearer \(association.token)", forHTTPHeaderField: "Authorization")
    }
    
    if !(body is EmptyBody) {
      request.httpBody = try encoder.encode(body)
    }
    
    do {
      let (data, response) = try await urlSession.data(for: request)
      
      guard let httpResponse = response as? HTTPURLResponse else {
        throw IDDigitalError.unexpectedResponse(statusCode: -1, responseBody: nil)
      }
      
      guard (200...299).contains(httpResponse.statusCode) else {
        let responseBody = String(data: data, encoding: .utf8)
        if let errorData = responseBody?.data(using: .utf8),
           let errorResponse = try? decoder.decode(ErrorResponse.self, from: errorData) {
          if errorResponse.code == "invalid-pin" {
            throw IDDigitalError.invalidPin(reason: "Incorrect PIN")
          }
          if errorResponse.code == "too-many-attempts" {
            throw IDDigitalError.tooManyAttempts
          }
        }
        
        
        switch httpResponse.statusCode {
        case 400, 404: throw IDDigitalError.badResponse(statusCode: httpResponse.statusCode, responseBody: responseBody)
        case 500...599: throw IDDigitalError.serviceUnavailable(statusCode: httpResponse.statusCode, responseBody: responseBody)
        default: throw IDDigitalError.unexpectedResponse(statusCode: httpResponse.statusCode, responseBody: responseBody)
        }
      }
      
      return (data, httpResponse)
    } catch {
      if error is IDDigitalError { throw error }
      throw error.toIDDigitalError()
    }
  }
}
