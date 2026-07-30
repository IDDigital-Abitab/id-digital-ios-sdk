import Foundation

struct PushPayload: Equatable {
  let transactionId: String
  let type: String
  let documentNumber: String?
  let documentType: String?
  let documentCountry: String?
}

enum PushPayloadKeys {
  static let transactionId = "idDigitalTransactionId"
  static let type = "idDigitalType"
  static let documentNumber = "idDigitalDocumentNumber"
  static let documentType = "idDigitalDocumentType"
  static let documentCountry = "idDigitalDocumentCountry"
}

extension PushPayload {
  init?(userInfo: [AnyHashable: Any]) {
    guard let transactionId = userInfo[PushPayloadKeys.transactionId] as? String,
          let type = userInfo[PushPayloadKeys.type] as? String else {
      return nil
    }
    let documentNumber = userInfo[PushPayloadKeys.documentNumber] as? String
    let documentType = userInfo[PushPayloadKeys.documentType] as? String
    let documentCountry = userInfo[PushPayloadKeys.documentCountry] as? String
    self.init(
      transactionId: transactionId,
      type: type,
      documentNumber: documentNumber,
      documentType: documentType,
      documentCountry: documentCountry
    )
  }
}
