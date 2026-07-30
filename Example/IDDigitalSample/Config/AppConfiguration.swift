import Foundation

enum AppConfiguration {
  static var apiKey: String {
    string(for: "API_KEY")
  }

  static var apiBaseURL: String? {
    let value = string(for: "API_BASE_URL")
    return value.isEmpty ? nil : value
  }

  static var keycloakBaseURL: String {
    string(for: "KEYCLOAK_BASE_URL", default: "https://bqm-keycloak-dev.alabamasolutions.com")
  }

  static var keycloakRealm: String {
    string(for: "KEYCLOAK_REALM", default: "bqm-realm")
  }

  static var keycloakClientID: String {
    string(for: "KEYCLOAK_CLIENT_ID")
  }

  static var keycloakRedirectURI: String {
    string(for: "KEYCLOAK_REDIRECT_URI", default: "iddigitalsample://auth")
  }

  static var isKeycloakConfigured: Bool {
    !keycloakClientID.isEmpty && !keycloakRedirectURI.isEmpty
  }

  private static func string(for key: String, default defaultValue: String = "") -> String {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
      return defaultValue
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("$(") {
      return defaultValue
    }
    return trimmed
  }
}
