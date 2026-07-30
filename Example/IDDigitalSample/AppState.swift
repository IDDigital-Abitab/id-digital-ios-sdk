import Foundation
import UIKit

@MainActor
final class AppState: ObservableObject {
  static let shared = AppState()

  @Published var keycloakRedirect: KeycloakRedirectResult?
  @Published var incomingPush: PushPayload?
  @Published var incomingDeepLink: DeepLinkPayload?
  @Published var pushTrigger = UUID()
  @Published var deepLinkTrigger = UUID()
  @Published var fcmToken: String?
  @Published var sdkInitialized = false
  @Published var sdkInitError: String?
  @Published var statusMessage: String?

  private init() {}

  func showStatus(_ message: String) {
    statusMessage = message
  }

  func handlePushPayload(_ payload: PushPayload) {
    incomingPush = payload
    pushTrigger = UUID()
  }

  func handleIncomingURL(_ url: URL) {
    if let redirect = KeycloakAuth.parseRedirect(url: url) {
      keycloakRedirect = redirect
      return
    }
    if let payload = DeepLinkHandler.payload(from: url) {
      incomingDeepLink = payload
      deepLinkTrigger = UUID()
    }
  }
}
