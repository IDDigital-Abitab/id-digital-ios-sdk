import IDDigitalSDK
import SwiftUI

struct ContentView: View {
  @ObservedObject private var appState = AppState.shared

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          if !appState.sdkInitialized {
            Text(appState.sdkInitError ?? "Inicializando SDK…")
              .foregroundStyle(.secondary)
          } else {
            PendingVerificationFlow()

            Text(appIdentity)
              .font(.footnote)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .center)
          }
        }
        .padding(24)
      }
      .navigationTitle("ID Digital — App de ejemplo")
      .alert(
        "Aviso",
        isPresented: Binding(
          get: { appState.statusMessage != nil },
          set: { if !$0 { appState.statusMessage = nil } }
        )
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(appState.statusMessage ?? "")
      }
    }
  }

  private var appIdentity: String {
    let bundleId = Bundle.main.bundleIdentifier ?? "-"
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    return "\(bundleId) · v\(version) (\(build))"
  }
}
