import IDDigitalSDK
import SwiftUI
import UIKit

private enum PendingVerificationType: String, CaseIterable, Identifiable {
  case association = "Asociación"
  case validation = "Validación"

  var id: String { rawValue }
}

private enum StepState: Equatable {
  case idle
  case running
  case done
  case failed(String)
}

struct PendingVerificationFlow: View {
  @ObservedObject private var appState = AppState.shared

  @State private var transactionId = ""
  @State private var pendingType: PendingVerificationType = .association
  @State private var challengeType: ChallengeType = .pin
  @State private var resolveStepState: StepState = .idle
  @State private var completeStepState: StepState = .idle
  @State private var qrStepState: StepState = .idle
  @State private var qrChallengeType: ChallengeType = .pin

  // Enruta el fallback QR igual que el deep link same-device (ver applyDeepLink): según el
  // estado local del dispositivo, no según si la transacción pendiente llegó por push. Se
  // refresca tras cada asociación exitosa (ver refreshDeviceAssociation) para no cachear un
  // valor stale si el usuario asocia y valida en la misma sesión.
  @State private var isDeviceAssociated = false

  private var isRunning: Bool {
    resolveStepState == .running || completeStepState == .running || qrStepState == .running
  }

  private var canSubmit: Bool {
    !transactionId.isEmpty && !isRunning
  }

  private var canScanQr: Bool {
    !isRunning
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      keycloakLoginSection

      Divider().padding(.vertical, 8)

      Text("Resolver verificación pendiente")
        .font(.title2)
      Text(
        "Estos campos se completan solos al llegar el push cross-device real " +
          "(ver README de este módulo). También se pueden completar a mano para " +
          "probar sin depender de FCM."
      )
      .font(.footnote)
      .foregroundStyle(.secondary)

      TextField("transactionId", text: $transactionId)
        .textFieldStyle(.roundedBorder)
        .disabled(isRunning)

      Picker("Tipo", selection: $pendingType) {
        ForEach(PendingVerificationType.allCases) { type in
          Text(type.rawValue).tag(type)
        }
      }
      .pickerStyle(.segmented)
      .disabled(isRunning)

      switch pendingType {
      case .association:
        Text(
          "El backend resuelve al ciudadano desde el transactionId (no hace falta " +
            "ningún dato de documento acá)."
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
      case .validation:
        Picker("Desafío", selection: $challengeType) {
          Text("Pin").tag(ChallengeType.pin)
          Text("Liveness").tag(ChallengeType.liveness)
        }
        .pickerStyle(.segmented)
        .disabled(isRunning)
      }

      Button("Resolver") {
        Task { await resolveAndComplete(openFinishUrl: true) }
      }
      .buttonStyle(.borderedProminent)
      .disabled(!canSubmit)

      stepRow(
        label: pendingType == .association ? "Asociar dispositivo" : "Crear sesión de validación",
        state: resolveStepState
      )
      stepRow(label: "Completar transacción", state: completeStepState)

      Divider().padding(.vertical, 8)

      Text("Fallback QR cross-device")
        .font(.title2)
      Text(
        "Independiente de todo lo anterior: no requiere transactionId ni haber recibido " +
          "una push. El SPA ofrece este QR en la pantalla de espera cuando la push (de " +
          "asociación o de validación) no se pudo confirmar entregada (sdk_push_failed) " +
          "— ver .docs/sdk/cliente/08-qr-cross-device.md. El camino se decide según el " +
          "estado local del dispositivo, no según el tipo de transacción pendiente: si ya " +
          "está asociado, se valida; si no, se asocia. La SDK escanea el token con su " +
          "propia cámara y hace todo el resto internamente (Liveness/PIN + " +
          "completeTransaction)."
      )
      .font(.footnote)
      .foregroundStyle(.secondary)

      if isDeviceAssociated {
        Text("Dispositivo asociado: se valida en vez de asociar.")
          .font(.footnote)
          .foregroundStyle(.secondary)

        Picker("Desafío", selection: $qrChallengeType) {
          Text("Pin").tag(ChallengeType.pin)
          Text("Liveness").tag(ChallengeType.liveness)
        }
        .pickerStyle(.segmented)
        .disabled(isRunning)

        Button("Escanear QR (validación)") {
          Task { await validateViaQrScan() }
        }
        .buttonStyle(.bordered)
        .disabled(!canScanQr)

        stepRow(label: "Escanear QR, validar y completar transacción", state: qrStepState)
      } else {
        Text(
          "Dispositivo sin asociación local: no hace falta ningún dato de documento " +
            "acá - el backend resuelve al ciudadano desde la transacción codificada " +
            "en el QR recién al escanearlo."
        )
        .font(.footnote)
        .foregroundStyle(.secondary)

        Button("Escanear QR (asociación)") {
          Task { await associateViaQrScan() }
        }
        .buttonStyle(.bordered)
        .disabled(!canScanQr)

        stepRow(label: "Escanear QR, asociar y completar transacción", state: qrStepState)
      }
    }
    .task {
      await refreshDeviceAssociation()
    }
    .onChange(of: appState.pushTrigger) { _ in
      guard let push = appState.incomingPush else { return }
      applyPush(push)
      Task { await resolveAndComplete(openFinishUrl: false) }
    }
    .onChange(of: appState.deepLinkTrigger) { _ in
      guard let link = appState.incomingDeepLink else { return }
      applyDeepLink(link)
    }
  }

  private var keycloakLoginSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Iniciar sesión")
        .font(.title2)
      Text(
        "Abre el login de Keycloak. El backend de ID Digital va a crear ahí la " +
          "transacción pendiente; copiá su id manualmente en el flujo de abajo."
      )
      .font(.footnote)
      .foregroundStyle(.secondary)

      Button("Iniciar sesión con Keycloak") {
        Task { await launchKeycloakLogin() }
      }
      .buttonStyle(.borderedProminent)

      if let redirect = appState.keycloakRedirect {
        switch redirect {
        case let .success(code, _):
          Text("Keycloak devolvió code=\(String(code.prefix(8)))…")
            .font(.footnote)
            .foregroundStyle(.blue)
        case let .error(error, description):
          Text("Keycloak devolvió un error: \(error) \(description ?? "")")
            .font(.footnote)
            .foregroundStyle(.red)
        }
      }
    }
  }

  @ViewBuilder
  private func stepRow(label: String, state: StepState) -> some View {
    HStack(spacing: 8) {
      switch state {
      case .idle:
        Image(systemName: "circle")
          .foregroundStyle(.secondary)
        Text(label)
          .font(.footnote)
      case .running:
        ProgressView()
        Text(label)
          .font(.footnote)
      case .done:
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
        Text(label)
          .font(.footnote)
      case let .failed(message):
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(.red)
        Text("\(label) — \(message)")
          .font(.footnote)
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  @MainActor
  private func launchKeycloakLogin() async {
    guard AppConfiguration.isKeycloakConfigured else {
      appState.showStatus("Falta configurar KEYCLOAK_CLIENT_ID/KEYCLOAK_REDIRECT_URI en Secrets.xcconfig")
      return
    }
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first(where: \.isKeyWindow) else {
      appState.showStatus("No se encontró una ventana para abrir Keycloak.")
      return
    }

    do {
      appState.keycloakRedirect = try await KeycloakAuth.launch(presentationAnchor: window)
    } catch {
      appState.showStatus(error.localizedDescription)
    }
  }

  private func applyPush(_ push: PushPayload) {
    transactionId = push.transactionId
    pendingType = push.type == "association" ? .association : .validation
  }

  private func applyDeepLink(_ link: DeepLinkPayload) {
    transactionId = link.transactionId
    Task {
      await refreshDeviceAssociation()
      await MainActor.run {
        pendingType = isDeviceAssociated ? .validation : .association
        Task { await resolveAndComplete(openFinishUrl: true) }
      }
    }
  }

  @MainActor
  private func refreshDeviceAssociation() async {
    isDeviceAssociated = await IDDigitalSDK.shared.isAssociated()
  }

  private func completeTransaction(validationSessionId: String, openFinishUrl: Bool) async {
    await MainActor.run { completeStepState = .running }
    do {
      let finishUrl = try await IDDigitalSDK.shared.completeTransaction(
        transactionId: transactionId,
        validationSessionId: validationSessionId
      )
      await MainActor.run {
        completeStepState = .done
        appState.showStatus("Transacción completada")
        if openFinishUrl, let finishUrl, let url = URL(string: finishUrl) {
          UIApplication.shared.open(url)
        }
      }
    } catch {
      await MainActor.run {
        completeStepState = .failed(error.localizedDescription)
        appState.showStatus(error.localizedDescription)
      }
    }
  }

  private func resolveAndComplete(openFinishUrl: Bool) async {
    await MainActor.run {
      resolveStepState = .running
      completeStepState = .idle
    }

    guard let viewController = await MainActor.run(body: { UIApplication.shared.topMostViewController }) else {
      await MainActor.run { resolveStepState = .failed("No hay view controller visible") }
      return
    }

    do {
      switch pendingType {
      case .association:
        let result = try await IDDigitalSDK.shared.associate(
          from: viewController,
          transactionId: transactionId
        )
        await MainActor.run { resolveStepState = .done }
        await refreshDeviceAssociation()
        await completeTransaction(validationSessionId: result.validationSessionId, openFinishUrl: openFinishUrl)
      case .validation:
        let validationSessionId = try await IDDigitalSDK.shared.createValidationSession(
          from: viewController,
          type: challengeType
        )
        await MainActor.run { resolveStepState = .done }
        await completeTransaction(validationSessionId: validationSessionId, openFinishUrl: openFinishUrl)
      }
    } catch {
      await MainActor.run {
        resolveStepState = .failed(error.localizedDescription)
        appState.showStatus(error.localizedDescription)
      }
    }
  }

  /// Fallback QR cross-device (ver .docs/sdk/cliente/08-qr-cross-device.md): el SPA lo
  /// ofrece cuando la push (de asociación o de validación) no se pudo confirmar entregada
  /// (sdk_push_failed=true). associateViaQrScan() reemplaza el paso de asociar() —
  /// decodifica el transactionId desde la cámara propia de la SDK y hace internamente
  /// Liveness/PIN + completeTransaction(), así que no hay nada más para orquestar acá.
  /// Siempre cross-device: nunca se abre finishUrl, el browser del otro dispositivo cierra
  /// por su propio polling. No requiere ningún dato de identificación por adelantado: el
  /// backend resuelve al citizen desde la transacción codificada en el QR recién al
  /// escanearlo.
  private func associateViaQrScan() async {
    await MainActor.run { qrStepState = .running }

    guard let viewController = await MainActor.run(body: { UIApplication.shared.topMostViewController }) else {
      await MainActor.run { qrStepState = .failed("No hay view controller visible") }
      return
    }

    do {
      let finishUrl = try await IDDigitalSDK.shared.associateViaQrScan(from: viewController)
      await MainActor.run {
        qrStepState = .done
        appState.showStatus("Transacción completada vía QR")
      }
      await refreshDeviceAssociation()
      print("QR cross-device finishUrl: \(finishUrl ?? "nil")")
    } catch {
      await MainActor.run {
        qrStepState = .failed(error.localizedDescription)
        appState.showStatus(error.localizedDescription)
      }
    }
  }

  /// Camino de validación del mismo fallback: se usa en vez de associateViaQrScan() cuando
  /// el dispositivo ya está asociado localmente (isDeviceAssociated) - no requiere
  /// Document, la asociación local ya identifica al citizen.
  private func validateViaQrScan() async {
    await MainActor.run { qrStepState = .running }

    guard let viewController = await MainActor.run(body: { UIApplication.shared.topMostViewController }) else {
      await MainActor.run { qrStepState = .failed("No hay view controller visible") }
      return
    }

    do {
      let finishUrl = try await IDDigitalSDK.shared.validateViaQrScan(from: viewController, type: qrChallengeType)
      await MainActor.run {
        qrStepState = .done
        appState.showStatus("Transacción completada vía QR")
      }
      print("QR cross-device finishUrl: \(finishUrl ?? "nil")")
    } catch {
      await MainActor.run {
        qrStepState = .failed(error.localizedDescription)
        appState.showStatus(error.localizedDescription)
      }
    }
  }
}
