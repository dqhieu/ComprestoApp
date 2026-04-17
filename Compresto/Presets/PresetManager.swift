//
//  PresetManager.swift
//  Compresto
//
//  Created by Claude on 18/03/2026.
//

import SwiftUI

class PresetManager: ObservableObject {

  static let shared = PresetManager()

  @AppStorage("savedCompressionPresets") var savedPresets: [CompressionPreset] = []
  @AppStorage("selectedPresetId") var selectedPresetId: String = ""

  // Current compression settings (read from same keys as CompressView)
  @AppStorage("imageQuality") private var imageQuality: ImageQuality = .highest
  @AppStorage("outputImageFormat") private var imageFormat: ImageFormat = .same
  @AppStorage("imageSize") private var imageSize: ImageSize = .same
  @AppStorage("imageSizeValue") private var imageSizeValue: Int = 100
  @AppStorage("videoQuality") private var videoQuality: VideoQuality = .high
  @AppStorage("outputFormat") private var videoFormat: VideoFormat = .same
  @AppStorage("videoDimension") private var videoDimension: VideoDimension = .same
  @AppStorage("videoDimensionValue") private var videoDimensionValue: Int = 1920
  @AppStorage("removeAudio") private var removeAudio: Bool = false
  @AppStorage("gifQuality") private var gifQuality: VideoQuality = .high
  @AppStorage("gifDimension") private var gifDimension: GifDimension = .same
  @AppStorage("pdfQuality") private var pdfQuality: PDFQuality = .balance

  var allPresets: [CompressionPreset] {
    CompressionPreset.builtInPresets + savedPresets
  }

  func preset(for id: String) -> CompressionPreset? {
    allPresets.first(where: { $0.id == id })
  }

  func captureCurrentSettings(name: String) -> CompressionPreset {
    CompressionPreset(
      name: name,
      imageQuality: imageQuality,
      imageFormat: imageFormat,
      imageSize: imageSize,
      imageSizeValue: imageSizeValue,
      videoQuality: videoQuality,
      videoFormat: videoFormat,
      videoDimension: videoDimension,
      videoDimensionValue: videoDimensionValue,
      removeAudio: removeAudio,
      gifQuality: gifQuality,
      gifDimension: gifDimension,
      pdfQuality: pdfQuality
    )
  }

  func savePreset(name: String) {
    let preset = captureCurrentSettings(name: name)
    savedPresets.append(preset)
    selectedPresetId = preset.id
  }

  func deletePreset(id: String) {
    savedPresets.removeAll(where: { $0.id == id })
    if selectedPresetId == id {
      selectedPresetId = ""
    }
  }

  func renamePreset(id: String, newName: String) {
    if let index = savedPresets.firstIndex(where: { $0.id == id }) {
      savedPresets[index].name = newName
    }
  }

  func updatePreset(_ preset: CompressionPreset) {
    if let index = savedPresets.firstIndex(where: { $0.id == preset.id }) {
      savedPresets[index] = preset
      if selectedPresetId == preset.id {
        applyPreset(preset)
      }
    }
  }

  func applyPreset(_ preset: CompressionPreset) {
    imageQuality = preset.imageQuality
    imageFormat = preset.imageFormat
    imageSize = preset.imageSize
    imageSizeValue = preset.imageSizeValue
    videoQuality = preset.videoQuality
    videoFormat = preset.videoFormat
    videoDimension = preset.videoDimension
    videoDimensionValue = preset.videoDimensionValue
    removeAudio = preset.removeAudio
    gifQuality = preset.gifQuality
    gifDimension = preset.gifDimension
    pdfQuality = preset.pdfQuality
    selectedPresetId = preset.id
  }
}
