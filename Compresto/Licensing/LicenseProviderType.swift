//
//  LicenseProviderType.swift
//  Compresto
//
//  Created by Claude on 25/12/2024.
//

import Foundation

enum LicenseProviderType: String, Codable {
  case lemonSqueezy = "lemonsqueezy"
  case polar = "polar"
  
  static func detect(from key: String) -> LicenseProviderType {
    key.uppercased().hasPrefix("POLAR") ? .polar : .lemonSqueezy
  }
}
