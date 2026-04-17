//
//  ImageQuality.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 1/8/24.
//


enum ImageQuality: String, CaseIterable, Codable {
  case highest
  case high
  case good
  case medium
  case acceptable

  var displayText: String {
    switch self {
    case .highest:
      return "Highest"
    case .high:
      return "High"
    case .good:
      return "Good"
    case .medium:
      return "Medium"
    case .acceptable:
      return "Acceptable"
    }
  }

  var jpgImageQualityLevel: String {
    switch self {
    case .highest:
      return "2"
    case .high:
      return "3"
    case .good:
      return "8"
    case .medium:
      return "12"
    case .acceptable:
      return "20"
    }
  }

  var avifFFmpegQualityLevel: String {
    switch self {
    case .highest:
      return "18"
    case .high:
      return "23"
    case .good:
      return "27"
    case .medium:
      return "35"
    case .acceptable:
      return "50"
    }
  }

  var pngFFmpegQualityLevel: String {
    switch self {
    case .highest:
      return "30"
    case .high:
      return "50"
    case .good:
      return "70"
    case .medium:
      return "80"
    case .acceptable:
      return "100"
    }
  }

  var pngImageQualityLevel: String {
    switch self {
    case .highest:
      return "0-90"
    case .high:
      return "0-75"
    case .good:
      return "0-60"
    case .medium:
      return "0-45"
    case .acceptable:
      return "0-30"
    }
  }

  var webPImageQualityLevel: Double {
    switch self {
    case .highest:
      return 0.9
    case .high:
      return 0.8
    case .good:
      return 0.7
    case .medium:
      return 0.6
    case .acceptable:
      return 0.3
    }
  }

  var svgImageQualityLevel: Double {
    switch self {
    case .highest:
      return 0.9
    case .high:
      return 0.8
    case .good:
      return 0.7
    case .medium:
      return 0.6
    case .acceptable:
      return 0.3
    }
  }
}
