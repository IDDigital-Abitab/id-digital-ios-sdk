import FirebaseCore
import FirebaseMessaging
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
      FirebaseApp.configure()
      PushNotificationHandler.shared.configure(application: application)
    } else {
      print("[IDDigitalSample] GoogleService-Info.plist missing — push FCM deshabilitado.")
    }

    if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any],
       let payload = PushPayload(userInfo: remoteNotification) {
      Task { @MainActor in
        AppState.shared.handlePushPayload(payload)
      }
    }

    return true
  }

  func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    Messaging.messaging().appDidReceiveMessage(userInfo)
    if let payload = PushPayload(userInfo: userInfo) {
      PushNotificationHandler.shared.showPendingVerificationNotification(payload)
      completionHandler(.newData)
    } else {
      completionHandler(.noData)
    }
  }
}
