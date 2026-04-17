//
//  LicenseProvider.swift
//  Compresto
//
//  Created by Claude on 25/12/2024.
//

import Foundation

protocol LicenseProvider {
    var providerType: LicenseProviderType { get }
    
    func activate(key: String, instanceName: String) async -> LicenseResult
    func validate(key: String, instanceId: String) async -> LicenseResult
    func deactivate(key: String, instanceId: String) async -> Bool
}
