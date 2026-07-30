import FirebaseMessaging
import IDDigitalSDK
import SwiftUI
import UIKit

struct DebugToolsView: View {
  @ObservedObject private var appState = AppState.shared

  @State private var debugTransactionId = ""
  @State private var manualTransactionID = ""
  @State private var manualValidationSessionID = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Herramientas / debug")
        .font(.title2)
      Text("Métodos de la SDK probados de forma aislada, fuera del flujo guiado de arriba.")
        .font(.footnote)
        .foregroundStyle(.secondary)

      copyFcmTokenButton

      // El backend resuelve el citizen desde esta transacción (via resolve_transaction_pk),
      // así que es el único dato que se necesita a mano para probar associate() de forma
      // aislada, ver .docs/sdk/cliente/04-invocacion-sdk.md.
      TextField("transactionId", text: $debugTransactionId)
        .textFieldStyle(.roundedBorder)

      Text("Asociación")
        .font(.title3)

      HStack {
        Button("Asociar") {
          Task { await associateDevice() }
        }
        .buttonStyle(.borderedProminent)
        .disabled(debugTransactionId.isEmpty)

        Button("Asociar vía QR") {
          Task { await associateViaQrScan() }
        }
        .buttonStyle(.bordered)
      }

      HStack {
        Button("¿Existe asociación?") {
          Task { await checkAssociation() }
        }
        .buttonStyle(.bordered)

        Button("Eliminar") {
          Task { await removeAssociation() }
        }
        .buttonStyle(.bordered)
        .tint(.red)
      }

      Divider()

      Text("Desafíos")
        .font(.title3)

      HStack {
        Button("Validar pin") {
          Task { await createValidationSession(type: .pin) }
        }
        .buttonStyle(.borderedProminent)

        Button("Validar liveness") {
          Task { await createValidationSession(type: .liveness) }
        }
        .buttonStyle(.borderedProminent)
      }

      HStack {
        Button("Validar pin vía QR") {
          Task { await validateViaQrScan(type: .pin) }
        }
        .buttonStyle(.bordered)

        Button("Validar liveness vía QR") {
          Task { await validateViaQrScan(type: .liveness) }
        }
        .buttonStyle(.bordered)
      }

      Divider()

      Text("Completar transacción (manual)")
        .font(.title3)

      TextField("Transaction ID", text: $manualTransactionID)
        .textFieldStyle(.roundedBorder)
      TextField("Validation Session ID", text: $manualValidationSessionID)
        .textFieldStyle(.roundedBorder)

      Button("Completar transacción") {
        Task { await completeTransactionManual() }
      }
      .buttonStyle(.borderedProminent)
      .disabled(manualTransactionID.isEmpty || manualValidationSessionID.isEmpty)
    }
  }

  private var copyFcmTokenButton: some View {
    Button("Copiar token FCM") {
      guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
        appState.showStatus("Falta GoogleService-Info.plist — ver Example/README.md")
        return
      }
      if let token = appState.fcmToken {
        UIPasteboard.general.string = token
        appState.showStatus("Token FCM copiado al portapapeles")
      } else {
        Messaging.messaging().token { token, error in
          Task { @MainActor in
            if let token {
              appState.fcmToken = token
              UIPasteboard.general.string = token
              appState.showStatus("Token FCM copiado al portapapeles")
            } else {
              appState.showStatus("Error al obtener token FCM: \(error?.localizedDescription ?? "desconocido")")
            }
          }
        }
      }
    }
    .buttonStyle(.bordered)
  }

  @MainActor
  private func presentingViewController() -> UIViewController? {
    UIApplication.shared.topMostViewController
  }

  private func associateDevice() async {
    guard let viewController = await presentingViewController() else { return }
    do {
      let result = try await IDDigitalSDK.shared.associate(
        from: viewController,
        transactionId: debugTransactionId
      )
      await MainActor.run {
        appState.showStatus("Dispositivo asociado. validationSessionId=\(result.validationSessionId)")
        debugTransactionId = ""
      }
    } catch {
      await MainActor.run { appState.showStatus(error.localizedDescription) }
    }
  }

  /// Fallback QR cross-device (ver .docs/sdk/cliente/08-qr-cross-device.md), probado de
  /// forma aislada: associateViaQrScan() reemplaza el paso de associate() (decodifica el
  /// transactionId con la cámara propia de la SDK, sin necesitar ningún dato de
  /// identificación por adelantado) y hace internamente Liveness/PIN +
  /// completeTransaction(); el finishUrl devuelto es solo informativo, nunca se abre.
  private func associateViaQrScan() async {
    guard let viewController = await presentingViewController() else { return }
    do {
      let finishUrl = try await IDDigitalSDK.shared.associateViaQrScan(from: viewController)
      await MainActor.run {
        appState.showStatus("Transacción completada vía QR. finishUrl=\(finishUrl ?? "nil")")
      }
    } catch {
      await MainActor.run { appState.showStatus(error.localizedDescription) }
    }
  }

  /// Camino de validación del mismo fallback QR (ver .docs/sdk/cliente/08-qr-cross-device.md),
  /// probado de forma aislada: validateViaQrScan() reemplaza el paso de
  /// createValidationSession() para un dispositivo ya asociado - no requiere Document, la
  /// asociación local ya identifica al citizen.
  private func validateViaQrScan(type: ChallengeType) async {
    guard let viewController = await presentingViewController() else { return }
    do {
      let finishUrl = try await IDDigitalSDK.shared.validateViaQrScan(from: viewController, type: type)
      await MainActor.run {
        appState.showStatus("Transacción completada vía QR. finishUrl=\(finishUrl ?? "nil")")
      }
    } catch {
      await MainActor.run { appState.showStatus(error.localizedDescription) }
    }
  }

  private func checkAssociation() async {
    let associated = await IDDigitalSDK.shared.isAssociated()
    await MainActor.run {
      appState.showStatus(associated ? "Usuario ya se encuentra asociado" : "No existe usuario asociado")
    }
  }

  private func removeAssociation() async {
    await IDDigitalSDK.shared.removeAssociation()
    await MainActor.run { appState.showStatus("Asociación eliminada") }
  }

  private func createValidationSession(type: ChallengeType) async {
    guard let viewController = await presentingViewController() else { return }
    do {
      let validationSessionId = try await IDDigitalSDK.shared.createValidationSession(
        from: viewController,
        type: type
      )
      await MainActor.run {
        appState.showStatus("Validation Session ID: \(validationSessionId)")
      }
    } catch {
      await MainActor.run { appState.showStatus(error.localizedDescription) }
    }
  }

  private func completeTransactionManual() async {
    do {
      let finishUrl = try await IDDigitalSDK.shared.completeTransaction(
        transactionId: manualTransactionID,
        validationSessionId: manualValidationSessionID
      )
      await MainActor.run {
        if let finishUrl {
          appState.showStatus("Transacción completada. finishUrl: \(finishUrl)")
        } else {
          appState.showStatus("Transacción completada (sin finishUrl)")
        }
      }
    } catch {
      await MainActor.run { appState.showStatus(error.localizedDescription) }
    }
  }
}
