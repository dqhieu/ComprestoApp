//
//  AIRenamingFilenameSanitizer.swift
//  Compresto
//

import Foundation

enum AIRenamingFilenameSanitizer {

  /// Sanitize an AI-suggested name into a safe kebab-case filename.
  /// Strips invalid characters, guards against path traversal, truncates UTF-8.
  static func sanitize(_ name: String, maxLength: Int = 100) -> String {
    var result = name
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()

    // Remove quotes and backticks
    result = result.replacingOccurrences(of: "\"", with: "")
    result = result.replacingOccurrences(of: "'", with: "")
    result = result.replacingOccurrences(of: "`", with: "")

    // Remove any file extension the AI might have added
    let knownExtensions = [".jpg", ".jpeg", ".png", ".webp", ".avif", ".gif", ".tiff", ".tif", ".heic", ".svg"]
    for ext in knownExtensions {
      if result.hasSuffix(ext) {
        result = String(result.dropLast(ext.count))
      }
    }

    // Replace spaces, underscores, dots with hyphens
    result = result
      .replacingOccurrences(of: " ", with: "-")
      .replacingOccurrences(of: "_", with: "-")
      .replacingOccurrences(of: ".", with: "-")

    // Keep only alphanumeric and hyphens
    result = result.unicodeScalars.filter { scalar in
      CharacterSet.alphanumerics.contains(scalar) || scalar == "-"
    }.map { String($0) }.joined()

    // Collapse multiple hyphens
    while result.contains("--") {
      result = result.replacingOccurrences(of: "--", with: "-")
    }

    // Strip leading/trailing hyphens
    result = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

    // Guard against path traversal
    result = result.replacingOccurrences(of: "..", with: "")

    // Truncate to maxLength respecting UTF-8 boundaries
    if result.count > maxLength {
      let index = result.index(result.startIndex, offsetBy: maxLength)
      result = String(result[..<index])
      // Trim trailing hyphen after truncation
      result = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    // Fallback
    if result.isEmpty {
      return "compressed-file"
    }

    return result
  }

  /// Resolve filename collision by appending -1, -2, etc.
  static func resolveCollision(name: String, extension ext: String, directory: URL) -> String {
    let baseURL = directory.appendingPathComponent("\(name).\(ext)")
    if !FileManager.default.fileExists(atPath: baseURL.path(percentEncoded: false)) {
      return name
    }
    for counter in 1...999 {
      let candidate = "\(name)-\(counter)"
      let candidateURL = directory.appendingPathComponent("\(candidate).\(ext)")
      if !FileManager.default.fileExists(atPath: candidateURL.path(percentEncoded: false)) {
        return candidate
      }
    }
    // Fallback: append random suffix to guarantee uniqueness
    return "\(name)-\(Int.random(in: 10000...99999))"
  }
}
