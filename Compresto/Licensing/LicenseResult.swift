//
//  LicenseResult.swift
//  Compresto
//
//  Created by Claude on 25/12/2024.
//

import Foundation

struct LicenseResult {
    let isValid: Bool
    let error: String?
    let instanceId: String
    let expiryDate: String?
    let status: String?
    let activationLimit: Int
    let activationUsage: Int
    let customerEmail: String?
    let productId: Int
    let productTier: ProductTier
    let providerType: LicenseProviderType
    /// True when validation failed due to network/connectivity issues, not a server rejection
    let isNetworkError: Bool

    init(isValid: Bool, error: String?, instanceId: String, expiryDate: String?,
         status: String?, activationLimit: Int, activationUsage: Int,
         customerEmail: String?, productId: Int, productTier: ProductTier,
         providerType: LicenseProviderType, isNetworkError: Bool = false) {
        self.isValid = isValid
        self.error = error
        self.instanceId = instanceId
        self.expiryDate = expiryDate
        self.status = status
        self.activationLimit = activationLimit
        self.activationUsage = activationUsage
        self.customerEmail = customerEmail
        self.productId = productId
        self.productTier = productTier
        self.providerType = providerType
        self.isNetworkError = isNetworkError
    }

    static func failure(error: String, provider: LicenseProviderType, isNetworkError: Bool = false) -> LicenseResult {
        LicenseResult(
            isValid: false,
            error: error,
            instanceId: "",
            expiryDate: nil,
            status: nil,
            activationLimit: 0,
            activationUsage: 0,
            customerEmail: nil,
            productId: 0,
            productTier: .unknown,
            providerType: provider,
            isNetworkError: isNetworkError
        )
    }
}

enum ProductTier: String, Codable {
    case lifetime
    case subscription
    case unknown
}
