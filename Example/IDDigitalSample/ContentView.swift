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

            Divider()

            DebugToolsView()
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
}
