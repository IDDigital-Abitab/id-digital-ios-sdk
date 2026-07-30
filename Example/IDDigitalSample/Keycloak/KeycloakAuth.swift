import AuthenticationServices
import CryptoKit
import Foundation

enum KeycloakRedirectResult: Equatable {
  case success(code: String, state: String?)
  case error(error: String, description: String?)
}

enum KeycloakAuth {
  static func parseRedirect(url: URL) -> KeycloakRedirectResult? {
    guard url.scheme?.lowercased() == "iddigitalsample" else {
      return nil
    }

    let isAuthRedirect = url.host?.lowercased() == "auth"
      || url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == "auth"
    guard isAuthRedirect else {
      return nil
    }

    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    if let code = components?.queryItems?.first(where: { $0.name == "code" })?.value {
      let state = components?.queryItems?.first(where: { $0.name == "state" })?.value
      return .success(code: code, state: state)
    }
    if let error = components?.queryItems?.first(where: { $0.name == "error" })?.value {
      let description = components?.queryItems?.first(where: { $0.name == "error_description" })?.value
      return .error(error: error, description: description)
    }
    return nil
  }

  @MainActor
  static func launch(presentationAnchor: ASPresentationAnchor) async throws -> KeycloakRedirectResult {
    let codeVerifier = randomURLSafeString(byteCount: 32)
    let codeChallenge = deriveCodeChallenge(codeVerifier: codeVerifier)
    let state = randomURLSafeString(byteCount: 16)

    var components = URLComponents(string: "\(AppConfiguration.keycloakBaseURL)/realms/\(AppConfiguration.keycloakRealm)/protocol/openid-connect/auth")!
    components.queryItems = [
      URLQueryItem(name: "client_id", value: AppConfiguration.keycloakClientID),
      URLQueryItem(name: "redirect_uri", value: AppConfiguration.keycloakRedirectURI),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "scope", value: "openid"),
      URLQueryItem(name: "state", value: state),
      URLQueryItem(name: "code_challenge", value: codeChallenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
    ]

    guard let authorizeURL = components.url else {
      throw KeycloakAuthError.invalidAuthorizeURL
    }

    return try await withCheckedThrowingContinuation { continuation in
      let session = ASWebAuthenticationSession(
        url: authorizeURL,
        callbackURLScheme: "iddigitalsample"
      ) { callbackURL, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        guard let callbackURL else {
          continuation.resume(throwing: KeycloakAuthError.missingCallbackURL)
          return
        }
        if let result = parseRedirect(url: callbackURL) {
          continuation.resume(returning: result)
        } else {
          continuation.resume(throwing: KeycloakAuthError.unrecognizedCallbackURL)
        }
      }
      session.presentationContextProvider = PresentationContextProvider(anchor: presentationAnchor)
      session.prefersEphemeralWebBrowserSession = false
      if !session.start() {
        continuation.resume(throwing: KeycloakAuthError.failedToStartSession)
      }
    }
  }

  private static func randomURLSafeString(byteCount: Int) -> String {
    var bytes = [UInt8](repeating: 0, count: byteCount)
    _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
    return Data(bytes)
      .base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  private static func deriveCodeChallenge(codeVerifier: String) -> String {
    let digest = SHA256.hash(data: Data(codeVerifier.utf8))
    return Data(digest)
      .base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}

enum KeycloakAuthError: LocalizedError {
  case invalidAuthorizeURL
  case missingCallbackURL
  case unrecognizedCallbackURL
  case failedToStartSession

  var errorDescription: String? {
    switch self {
    case .invalidAuthorizeURL: return "No se pudo armar la URL de authorize de Keycloak."
    case .missingCallbackURL: return "Keycloak no devolvió un redirect."
    case .unrecognizedCallbackURL: return "El redirect de Keycloak no es reconocible."
    case .failedToStartSession: return "No se pudo abrir la sesión de login."
    }
  }
}

private final class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
  private let anchor: ASPresentationAnchor

  init(anchor: ASPresentationAnchor) {
    self.anchor = anchor
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    anchor
  }
}
