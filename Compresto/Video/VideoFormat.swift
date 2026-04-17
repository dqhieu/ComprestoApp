//
//  VideoFormat.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 1/8/24.
//


enum VideoFormat: String, CaseIterable, Codable {
  case same
  case mp4
  case webm
  case gif
  case mov
  case mp3  // Audio extraction format

  var displayText: String {
    switch self {
    case .same:
      return "Same as input"
    case .mp4:
      return "MP4"
    case .webm:
      return "WebM"
    case .gif:
      return "GIF"
    case .mov:
      return "MOV"
    case .mp3:
      return "MP3 (Audio)"
    }
  }

  static var allVideoCases: [VideoFormat] = [
    .same,
    .mp4,
    .webm,
    .mov
  ]
}
