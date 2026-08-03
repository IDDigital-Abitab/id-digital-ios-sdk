import IDDigitalSDK
import SwiftUI

@main
struct IDDigitalSampleApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @ObservedObject private var appState = AppState.shared

  var body: some Scene {
    WindowGroup {
      ContentView()
        .task {
          await initializeSDKIfNeeded()
        }
        .onOpenURL { url in
          appState.handleIncomingURL(url)
        }
    }
  }

  private func initializeSDKIfNeeded() async {
    guard !appState.sdkInitialized, appState.sdkInitError == nil else { return }

    let apiKey = AppConfiguration.apiKey
    guard !apiKey.isEmpty else {
      appState.sdkInitError = "Falta API_KEY en Secrets.xcconfig"
      return
    }
    guard let environment = AppConfiguration.sdkEnvironment else {
      appState.sdkInitError = "SDK_ENVIRONMENT debe ser STAGING o PRODUCTION"
      return
    }

    do {
      try await IDDigitalSDK.shared.initialize(
        apiKey: apiKey,
        environment: environment,
        baseUrl: AppConfiguration.apiBaseURL
      )
      appState.sdkInitialized = true
    } catch {
      appState.sdkInitError = "Error initializing IDDigitalSDK: \(error.localizedDescription)"
    }
  }
}
