//
//  AIRenamingPreset.swift
//  Compresto
//

import Foundation

enum AIRenamingPreset: String, CaseIterable, Identifiable {
  case descriptive
  case seoFriendly
  case short
  case technical
  case custom

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .descriptive: return "Descriptive"
    case .seoFriendly: return "SEO Friendly"
    case .short: return "Short"
    case .technical: return "Technical"
    case .custom: return "Custom"
    }
  }

  var systemPrompt: String {
    let baseInstruction = "You are a file naming assistant. Always respond in English. Return ONLY the filename without extension and without quotes."

    switch self {
    case .descriptive:
      return "\(baseInstruction) Describe the main subject, action, and mood of the image in kebab-case. Example: sunset-beach-golden-hour"
    case .seoFriendly:
      return "\(baseInstruction) Create an SEO-optimized filename using relevant keywords in kebab-case. Example: professional-team-meeting-office"
    case .short:
      return "\(baseInstruction) Create a short 2-3 word filename in kebab-case. Example: beach-sunset"
    case .technical:
      return "\(baseInstruction) Describe the technical aspects like composition, lighting, and subject in kebab-case. Example: wide-angle-low-light-portrait"
    case .custom:
      return baseInstruction
    }
  }
}
