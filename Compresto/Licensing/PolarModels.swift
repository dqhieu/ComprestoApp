//
//  PolarModels.swift
//  Compresto
//
//  Created by Claude on 25/12/2024.
//

import Foundation

struct PolarUser: Decodable {
    let id: String
    let email: String
    let public_name: String?
    let avatar_url: String?
}

struct PolarCustomer: Decodable {
    let id: String
    let email: String
    let name: String?
    let avatar_url: String?
}

struct PolarActivateResponse: Decodable {
    let id: String
    let license_key_id: String
    let label: String
    let meta: [String: String]?
    let created_at: String
    let modified_at: String?
    let license_key: PolarLicenseKey
}

struct PolarValidateResponse: Decodable {
    let id: String
    let organization_id: String
    let user_id: String
    let customer_id: String?
    let user: PolarUser?
    let customer: PolarCustomer?
    let status: String
    let limit_activations: Int?
    let usage: Int
    let validations: Int?
    let last_validated_at: String?
    let expires_at: String?
    let activation: PolarActivation?
}

struct PolarLicenseKey: Decodable {
    let id: String
    let user: PolarUser?
    let customer: PolarCustomer?
    let status: String
    let limit_activations: Int?
    let usage: Int
    let validations: Int?
    let last_validated_at: String?
    let expires_at: String?
}

struct PolarActivation: Decodable {
    let id: String
    let license_key_id: String
    let label: String
    let meta: [String: String]?
    let created_at: String
    let modified_at: String?
}

struct PolarErrorResponse: Decodable {
    let detail: String?
    let error: String?
}
