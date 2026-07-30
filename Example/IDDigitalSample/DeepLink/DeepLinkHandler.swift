import Foundation
import IDDigitalSDK

struct DeepLinkPayload: Equatable {
  let transactionId: String
}

enum DeepLinkHandler {
  static func payload(from url: URL) -> DeepLinkPayload? {
    guard url.scheme?.lowercased() == "iddigitalsample",
          url.host?.lowercased() == "sdkauth",
          let transactionId = IDDigitalSDK.parseAuthenticationLink(url: url) else {
      return nil
    }
    return DeepLinkPayload(transactionId: transactionId)
  }
}
