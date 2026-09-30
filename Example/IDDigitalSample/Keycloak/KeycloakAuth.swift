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
      let attempt = LoginAttempt(anchor: presentationAnchor)
      let session = ASWebAuthenticationSession(
        url: authorizeURL,
        callbackURLScheme: "iddigitalsample"
      ) { callbackURL, error in
        attempt.finish {
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
            return
          }
          // El scheme iddigitalsample también lo usa el deep link same-device.
          // La sesión se queda con esa URL y, si el callback entra otra vez, el
          // segundo resume mata la app.
          if DeepLinkHandler.payload(from: callbackURL) != nil {
            AppState.shared.handleIncomingURL(callbackURL)
            continuation.resume(throwing: KeycloakAuthError.followedDeepLink)
            return
          }
          continuation.resume(throwing: KeycloakAuthError.unrecognizedCallbackURL)
        }
      }

      attempt.session = session
      session.presentationContextProvider = attempt
      session.prefersEphemeralWebBrowserSession = false

      if !session.start() {
        attempt.finish {
          continuation.resume(throwing: KeycloakAuthError.failedToStartSession)
        }
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
  case followedDeepLink

  var errorDescription: String? {
    switch self {
    case .invalidAuthorizeURL: return "No se pudo armar la URL de authorize de Keycloak."
    case .missingCallbackURL: return "Keycloak no devolvió un redirect."
    case .unrecognizedCallbackURL: return "El redirect de Keycloak no es reconocible."
    case .failedToStartSession: return "No se pudo abrir la sesión de login."
    case .followedDeepLink: return nil
    }
  }
}

private final class LoginAttempt: NSObject, ASWebAuthenticationPresentationContextProviding {
  let anchor: ASPresentationAnchor
  var session: ASWebAuthenticationSession?
  private var didResume = false

  init(anchor: ASPresentationAnchor) {
    self.anchor = anchor
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    anchor
  }

  func finish(_ body: () -> Void) {
    guard !didResume else { return }
    didResume = true
    body()
    session = nil
  }
}
