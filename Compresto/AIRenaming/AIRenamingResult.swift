//
//  AIRenamingResult.swift
//  Compresto
//

import Foundation

struct AIRenamingResult {
  let suggestedName: String?
  let sanitizedName: String?
  let error: String?
  let tokensUsed: Int

  static func success(suggested: String, sanitized: String, tokens: Int = 0) -> AIRenamingResult {
    AIRenamingResult(suggestedName: suggested, sanitizedName: sanitized, error: nil, tokensUsed: tokens)
  }

  static func failure(error: String) -> AIRenamingResult {
    AIRenamingResult(suggestedName: nil, sanitizedName: nil, error: error, tokensUsed: 0)
  }
}
