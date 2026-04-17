//
//  AIRenamingProviderType.swift
//  Compresto
//

import Foundation

enum AIRenamingProviderType: String, CaseIterable, Identifiable {
  case openai
  case anthropic
  case google

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .openai: return "OpenAI"
    case .anthropic: return "Anthropic"
    case .google: return "Google"
    }
  }

  var defaultModel: String {
    switch self {
    case .openai: return OpenAIModel.gpt5Nano.rawValue
    case .anthropic: return "claude-3-haiku-20240307"
    case .google: return "gemini-1.5-flash"
    }
  }

  var isImplemented: Bool {
    switch self {
    case .openai: return true
    case .anthropic, .google: return false
    }
  }
}

/// Available OpenAI models for AI renaming (vision-capable, GPT-5 family)
enum OpenAIModel: String, CaseIterable, Identifiable {
  case gpt5Nano = "gpt-5-nano"
  case gpt5Mini = "gpt-5-mini"
  case gpt5 = "gpt-5"
  case gpt51 = "gpt-5.1"
  case gpt52 = "gpt-5.2"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .gpt5Nano: return "GPT-5 Nano"
    case .gpt5Mini: return "GPT-5 Mini"
    case .gpt5: return "GPT-5"
    case .gpt51: return "GPT-5.1"
    case .gpt52: return "GPT-5.2"
    }
  }

  var costDescription: String {
    switch self {
    case .gpt5Nano: return "Cheapest — ~$0.00001/image"
    case .gpt5Mini: return "Balanced — ~$0.00005/image"
    case .gpt5: return "Premium — ~$0.0003/image"
    case .gpt51: return "Premium — ~$0.0003/image"
    case .gpt52: return "Most capable — ~$0.0004/image"
    }
  }
}
