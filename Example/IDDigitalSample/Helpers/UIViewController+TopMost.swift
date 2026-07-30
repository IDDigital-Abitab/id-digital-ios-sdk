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
}
