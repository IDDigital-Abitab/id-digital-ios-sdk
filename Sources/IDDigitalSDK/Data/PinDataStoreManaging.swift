import Foundation
import Security

protocol PinDataStoreManaging {
    func savePinAndBiometricPreference(pin: String, isEnabled: Bool) async
    func isBiometricPinEnabled() async -> Bool
    func getDecryptedPin() async -> String?
    func saveLastBiometricUsage() async
    func getLastBiometricUsage() async -> Date?
    func clearAll() async
}

actor PinDataStoreManager: PinDataStoreManaging {
    private let keychainService = "com.abitab.iddigitalsdk.pin"
    private let pinAccount = "userPin"
    private let biometricEnabledAccount = "biometricEnabled"
    private let lastBiometricUsageAccount = "lastBiometricUsage"

    func savePinAndBiometricPreference(pin: String, isEnabled: Bool) async {
        // Save the PIN
        if let pinData = pin.data(using: .utf8) {
            save(data: pinData, for: pinAccount)
        }

        // Save the biometric preference
        let isEnabledData = withUnsafeBytes(of: isEnabled) { Data($0) }
        save(data: isEnabledData, for: biometricEnabledAccount)
        
        // When saving a new PIN preference, also update the last usage date.
        if isEnabled {
            await saveLastBiometricUsage()
        }
    }

    func isBiometricPinEnabled() async -> Bool {
        guard let data = readData(for: biometricEnabledAccount) else { return false }
        return data.withUnsafeBytes { $0.load(as: Bool.self) }
    }

    func getDecryptedPin() async -> String? {
        guard let data = readData(for: pinAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveLastBiometricUsage() async {
        let now = Date()
        let data = withUnsafeBytes(of: now.timeIntervalSince1970) { Data($0) }
        save(data: data, for: lastBiometricUsageAccount)
    }

    func getLastBiometricUsage() async -> Date? {
        guard let data = readData(for: lastBiometricUsageAccount) else { return nil }
        let timeInterval = data.withUnsafeBytes { $0.load(as: TimeInterval.self) }
        return Date(timeIntervalSince1970: timeInterval)
    }
    
    func clearAll() async {
        delete(for: pinAccount)
        delete(for: biometricEnabledAccount)
        delete(for: lastBiometricUsageAccount)
    }

    // MARK: - Keychain Helpers
    private func save(data: Data, for account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain save failed for account \(account) with status: \(status)")
        }
    }

    private func readData(for account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        return status == errSecSuccess ? dataTypeRef as? Data : nil
    }
    
    private func delete(for account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
