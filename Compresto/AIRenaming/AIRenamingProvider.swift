//
//  AIRenamingProvider.swift
//  Compresto
//

import Foundation

protocol AIRenamingProvider {
  var providerType: AIRenamingProviderType { get }

  func generateName(
    imageData: Data,
    mimeType: String,
    preset: AIRenamingPreset,
    customPrompt: String?
  ) async -> AIRenamingResult

  func validateAPIKey(_ key: String) async -> Bool
}
