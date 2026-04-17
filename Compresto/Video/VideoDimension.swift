//
//  VideoDimension.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 1/8/24.
//


enum VideoDimension: String, CaseIterable, Codable {
  case same
  case ultraHD
  case fullHD
  case HD
  case maxWidth
  case maxHeight
  case maxLongEdge
  case maxShortEdge

  var displayText: String {
    switch self {
    case .same:
      return "Same as input"
    case .ultraHD:
      return "4K (2160p)"
    case .fullHD:
      return "Full HD (1080p)"
    case .HD:
      return "HD (720p)"
    case .maxWidth:
      return "Max width"
    case .maxHeight:
      return "Max height"
    case .maxLongEdge:
      return "Max long edge"
    case .maxShortEdge:
      return "Max short edge"
    }
  }

  var needsCustomValue: Bool {
    switch self {
    case .maxWidth, .maxHeight, .maxLongEdge, .maxShortEdge:
      return true
    default:
      return false
    }
  }
}
