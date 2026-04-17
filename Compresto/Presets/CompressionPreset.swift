//
//  CompressionPreset.swift
//  Compresto
//
//  Created by Claude on 18/03/2026.
//

import Foundation

struct CompressionPreset: Codable, Identifiable, Hashable {
  var id: String = UUID().uuidString
  var name: String
  var isBuiltIn: Bool = false

  // Image
  var imageQuality: ImageQuality
  var imageFormat: ImageFormat
  var imageSize: ImageSize
  var imageSizeValue: Int

  // Video
  var videoQuality: VideoQuality
  var videoFormat: VideoFormat
  var videoDimension: VideoDimension
  var videoDimensionValue: Int
  var removeAudio: Bool

  // GIF
  var gifQuality: VideoQuality
  var gifDimension: GifDimension

  // PDF
  var pdfQuality: PDFQuality

  var summary: String {
    var parts: [String] = []
    parts.append("Image: \(imageQuality.displayText)/\(imageFormat.displayText)")
    parts.append("Video: \(videoQuality.displayText)/\(videoFormat.displayText)")
    parts.append("GIF: \(gifQuality.displayText)")
    parts.append("PDF: \(pdfQuality.displayText)")
    return parts.joined(separator: " | ")
  }
}

// MARK: - Built-in Presets

extension CompressionPreset {

  static let webOptimized = CompressionPreset(
    id: "builtin-web-optimized",
    name: "Web Optimized",
    isBuiltIn: true,
    imageQuality: .good,
    imageFormat: .webp,
    imageSize: .same,
    imageSizeValue: 100,
    videoQuality: .good,
    videoFormat: .mp4,
    videoDimension: .fullHD,
    videoDimensionValue: 1920,
    removeAudio: false,
    gifQuality: .good,
    gifDimension: .half,
    pdfQuality: .balance
  )

  static let highQuality = CompressionPreset(
    id: "builtin-high-quality",
    name: "High Quality",
    isBuiltIn: true,
    imageQuality: .highest,
    imageFormat: .same,
    imageSize: .same,
    imageSizeValue: 100,
    videoQuality: .highest,
    videoFormat: .same,
    videoDimension: .same,
    videoDimensionValue: 1920,
    removeAudio: false,
    gifQuality: .highest,
    gifDimension: .same,
    pdfQuality: .best
  )

  static let smallestFileSize = CompressionPreset(
    id: "builtin-smallest-file-size",
    name: "Smallest File Size",
    isBuiltIn: true,
    imageQuality: .acceptable,
    imageFormat: .webp,
    imageSize: .same,
    imageSizeValue: 100,
    videoQuality: .acceptable,
    videoFormat: .mp4,
    videoDimension: .same,
    videoDimensionValue: 1920,
    removeAudio: true,
    gifQuality: .acceptable,
    gifDimension: .half,
    pdfQuality: .low
  )

  static let builtInPresets: [CompressionPreset] = [
    .highQuality,
    .webOptimized,
    .smallestFileSize,
  ]
}
