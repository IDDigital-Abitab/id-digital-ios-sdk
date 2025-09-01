import Foundation
import Security
import CryptoKit

protocol DeviceIdentifierProviding {
  func getDeviceFingerprint() async -> String
}

final class DeviceIdentifierProvider: DeviceIdentifierProviding {
  // Keychain constants to identify the stored item.
  private let keychainService = "com.abitab.iddigitalsdk"
  private let keychainAccount = "installationUUID"
  
  func getDeviceFingerprint() async -> String {
    let uuid = await getAppSpecificUUID()
    return hashString(input: uuid)
  }
  
  private func getAppSpecificUUID() async -> String {
    // Try to read from Keychain first.
    if let existingUUID = readUUIDFromKeychain() {
      return existingUUID
    }
    
    // If not found, create a new one and save it.
    let newUUID = UUID().uuidString
    saveUUIDToKeychain(uuid: newUUID)
    return newUUID
  }
  
  private func hashString(input: String) -> String {
    guard let data = input.data(using: .utf8) else { return input }
    let digest = SHA256.hash(data: data)
    return digest.compactMap { String(format: "%02x", $0) }.joined()
  }
  
  // MARK: - Keychain Helpers
  private func saveUUIDToKeychain(uuid: String) {
    guard let data = uuid.data(using: .utf8) else { return }
    
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecValueData as String: data
    ]
    
    // Delete any old item before saving a new one.
    SecItemDelete(query as CFDictionary)
    
    // Add the new item.
    SecItemAdd(query as CFDictionary, nil)
  }
  
  private func readUUIDFromKeychain() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecReturnData as String: kCFBooleanTrue!,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
    
    var dataTypeRef: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
    
    if status == errSecSuccess, let data = dataTypeRef as? Data {
      return String(data: data, encoding: .utf8)
    }
    
    return nil
  }
}
