import UIKit

extension UIApplication {
  var topMostViewController: UIViewController? {
    connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController?
      .topMostPresentedViewController
  }

  /// El view controller de la sample, cuando ya no está encima la sesión de
  /// Keycloak. Presentar ahí mientras `SFAuthenticationViewController` se
  /// cierra falla: su vista ya no está en la ventana.
  @MainActor
  func samplePresenter() async -> UIViewController? {
    let root = connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController
    for _ in 0..<25 {
      if let presenter = root?.presenterReadyForSampleFlow() {
        return presenter
      }
      try? await Task.sleep(nanoseconds: 100_000_000)
    }
    return root
  }
}

extension UIViewController {
  var topMostPresentedViewController: UIViewController {
    if let presented = presentedViewController {
      return presented.topMostPresentedViewController
    }
    if let navigation = self as? UINavigationController, let visible = navigation.visibleViewController {
      return visible.topMostPresentedViewController
    }
    if let tab = self as? UITabBarController, let selected = tab.selectedViewController {
      return selected.topMostPresentedViewController
    }
    return self
  }

  func presenterReadyForSampleFlow() -> UIViewController? {
    if let presented = presentedViewController {
      let top = presented.topMostPresentedViewController
      let name = String(describing: type(of: top))
      if name.contains("SFAuthentication") || top.viewIfLoaded?.window == nil {
        return nil
      }
      return top
    }
    guard viewIfLoaded?.window != nil else { return nil }
    return self
  }
}
