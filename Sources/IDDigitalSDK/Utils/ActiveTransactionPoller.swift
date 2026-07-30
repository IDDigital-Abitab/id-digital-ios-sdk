import Foundation
import UIKit
import FactoryKit

/// Polling de "transacción activa": canal redundante al push que replica el
/// mecanismo ya usado por la app default de ID Digital (ver
/// .docs/sdk/cliente/09-polling-transaccion-activa.md). Solo cubre login
/// recurrente (validation): un dispositivo sin asociar no tiene bearer token
/// contra el cual preguntar, así que mientras no haya asociación el polling
/// queda en espera silenciosa (no es un error).
///
/// Se pausa/reanuda automáticamente con el foreground/background de la app
/// (`UIApplication.didBecomeActiveNotification` / `willResignActiveNotification`),
/// igual que el gate `appState === 'active'` de la app RN. Se detiene a sí
/// mismo apenas reporta una transacción, para no volver a dispararla en cada
/// tick mientras el Integrador la está resolviendo - llamar `start` de nuevo
/// para volver a habilitarlo (p. ej. tras cerrar esa transacción con
/// `completeTransaction`).
actor ActiveTransactionPoller {
  static let defaultIntervalMs: UInt64 = 10_000

  private var intervalMs: UInt64 = ActiveTransactionPoller.defaultIntervalMs
  private var onTransactionDetected: (@Sendable (String) -> Void)?
  private var isForeground = true
  private var isEnabled = false
  private var pollingTask: Task<Void, Never>?
  private var lifecycleObservers: [NSObjectProtocol] = []

  deinit {
    let center = NotificationCenter.default
    lifecycleObservers.forEach { center.removeObserver($0) }
  }

  func start(intervalMs: UInt64, onTransactionDetected: @escaping @Sendable (String) -> Void) {
    installLifecycleObserversIfNeeded()
    self.intervalMs = intervalMs
    self.onTransactionDetected = onTransactionDetected
    isEnabled = true
    restartIfNeeded()
  }

  func stop() {
    isEnabled = false
    onTransactionDetected = nil
    pollingTask?.cancel()
    pollingTask = nil
  }

  private func installLifecycleObserversIfNeeded() {
    guard lifecycleObservers.isEmpty else { return }

    let center = NotificationCenter.default
    let didBecomeActive = center.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { await self?.handleForeground() }
    }
    let willResignActive = center.addObserver(
      forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { await self?.handleBackground() }
    }
    lifecycleObservers = [didBecomeActive, willResignActive]
  }

  private func handleForeground() {
    isForeground = true
    restartIfNeeded()
  }

  private func handleBackground() {
    isForeground = false
    pollingTask?.cancel()
    pollingTask = nil
  }

  private func restartIfNeeded() {
    guard isEnabled, isForeground, pollingTask == nil else { return }

    pollingTask = Task { [weak self] in
      while let self, !Task.isCancelled {
        guard let sleepNanoseconds = await self.tick() else { return }
        try? await Task.sleep(nanoseconds: sleepNanoseconds)
      }
    }
  }

  /// Runs a single poll tick; returns the delay (ns) to wait before the next
  /// one, or nil once a transaction was found and reported (loop stops).
  private func tick() async -> UInt64? {
    do {
      let deviceAssociationStorage = Container.shared.deviceAssociationStorage()
      // Silencioso si todavía no hay asociación: no hay bearer token contra
      // el cual preguntar (ver docstring del actor). No es un error - solo
      // se espera al próximo tick.
      if await deviceAssociationStorage.get() != nil {
        let useCase = Container.shared.getPendingTransactionsUseCase()
        if let oldest = try await useCase.execute().first {
          let callback = onTransactionDetected
          isEnabled = false
          onTransactionDetected = nil
          pollingTask = nil
          callback?(oldest.id)
          return nil
        }
      }
    } catch {
      print("[IDDigitalSDK] Error polling active transactions: \(error.localizedDescription)")
    }
    return intervalMs * 1_000_000
  }
}
