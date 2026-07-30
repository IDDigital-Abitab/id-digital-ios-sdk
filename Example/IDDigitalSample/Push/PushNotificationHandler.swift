import FirebaseMessaging
import UIKit
import UserNotifications

final class PushNotificationHandler: NSObject {
  static let shared = PushNotificationHandler()

  private let notificationCenter = UNUserNotificationCenter.current()
  private let channelID = "id_digital_sample_pending_verification"

  private override init() {
    super.init()
  }

  func configure(application: UIApplication) {
    notificationCenter.delegate = self
    Messaging.messaging().delegate = self
    application.registerForRemoteNotifications()
    createNotificationChannelIfNeeded()
    requestAuthorization()
  }

  private func requestAuthorization() {
    notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
  }

  private func createNotificationChannelIfNeeded() {
    let category = UNNotificationCategory(
      identifier: channelID,
      actions: [],
      intentIdentifiers: [],
      options: []
    )
    notificationCenter.setNotificationCategories([category])
  }

  func showPendingVerificationNotification(_ payload: PushPayload) {
    let content = UNMutableNotificationContent()
    content.title = "ID Digital — App de ejemplo"
    content.body = payload.type == "association"
      ? "Asociá tu identidad digital para continuar"
      : "Confirmá tu identidad para continuar"
    content.userInfo = [
      PushPayloadKeys.transactionId: payload.transactionId,
      PushPayloadKeys.type: payload.type,
      PushPayloadKeys.documentNumber: payload.documentNumber as Any,
      PushPayloadKeys.documentType: payload.documentType as Any,
      PushPayloadKeys.documentCountry: payload.documentCountry as Any,
    ]
    content.categoryIdentifier = channelID
    content.sound = .default

    let request = UNNotificationRequest(
      identifier: "pending-verification-\(payload.transactionId)",
      content: content,
      trigger: nil
    )
    notificationCenter.add(request)
  }
}

extension PushNotificationHandler: UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let payload = PushPayload(userInfo: response.notification.request.content.userInfo) {
      Task { @MainActor in
        AppState.shared.handlePushPayload(payload)
      }
    }
    completionHandler()
  }
}

extension PushNotificationHandler: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    Task { @MainActor in
      AppState.shared.fcmToken = fcmToken
    }
  }
}

extension AppDelegate {
  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[IDDigitalSample] APNs registration failed: \(error.localizedDescription)")
  }
}
