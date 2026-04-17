//
//  ImageFormat.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 1/8/24.
//


enum ImageFormat: String, CaseIterable, Codable {
  case same
  case jpg
  case png
  case webp
  case avif

  var displayText: String {
    switch self {
    case .same:
      return "Same as input"
    case .jpg:
      return "JPG"
    case .png:
      return "PNG"
    case .webp:
      return "WebP"
    case .avif:
      return "AVIF"
    }
  }

}
