import Security
import Foundation

protocol DeviceAssociationStoring {
    func save(association: DeviceAssociation) async
    func get() async -> DeviceAssociation?
    func remove() async
}

actor DeviceAssociationStorage: DeviceAssociationStoring {
    private let keychainService = "uy.com.abitab.iddigitalsdk"
    private let keychainAccount = "currentAssociation"
    
    func save(association: DeviceAssociation) async {
        do {
            let data = try JSONEncoder().encode(association)
            
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: keychainAccount,
                kSecValueData as String: data
            ]
            
            SecItemDelete(query as CFDictionary)
            
            let status = SecItemAdd(query as CFDictionary, nil)
            if status != errSecSuccess {
                print("Error saving to Keychain: \(status)")
            }
        } catch {
            print("Error encoding DeviceAssociation: \(error)")
        }
    }
    
    func get() async -> DeviceAssociation? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(DeviceAssociation.self, from: data)
        } catch {
            print("Error decoding DeviceAssociation: \(error)")
            return nil
        }
    }
    
    func remove() async {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
