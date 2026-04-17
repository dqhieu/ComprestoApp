//
//  KeychainHelper.swift
//  Compresto
//

import Foundation
import Security

final class KeychainHelper {
  static let shared = KeychainHelper()
  private let service = "com.compresto.ai-renaming"

  private init() {}

  func save(_ data: String, for key: String) {
    guard let valueData = data.data(using: .utf8) else { return }
    delete(key)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecValueData as String: valueData
    ]
    SecItemAdd(query as CFDictionary, nil)
  }

  func retrieve(for key: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  func delete(_ key: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key
    ]
    SecItemDelete(query as CFDictionary)
  }
}
