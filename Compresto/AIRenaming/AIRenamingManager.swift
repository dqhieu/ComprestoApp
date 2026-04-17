//
//  AIRenamingManager.swift
//  Compresto
//

import AppKit
import Foundation
import SwiftUI
import Darwin

final class AIRenamingManager: ObservableObject {
  static let shared = AIRenamingManager()

  // MARK: - Settings (persisted via @AppStorage)

  @AppStorage("aiRenaming_enabled") var aiRenamingEnabled = false
  @AppStorage("aiRenaming_providerType") var providerTypeRaw: String = AIRenamingProviderType.openai.rawValue
  @AppStorage("aiRenaming_preset") var presetRaw: String = AIRenamingPreset.descriptive.rawValue
  @AppStorage("aiRenaming_customPrompt") var customPrompt: String = ""
  @AppStorage("aiRenaming_openaiModel") var openaiModelRaw: String = OpenAIModel.gpt5Nano.rawValue
  @AppStorage("aiRenaming_maxFilenameLength") var maxFilenameLength: Int = 100

  // MARK: - Observable state

  @Published var isVerifyingKey = false
  @Published var keyVerificationResult: Bool?

  // MARK: - Keychain keys

  private let keychainKeyPrefix = "ai-renaming-"

  // MARK: - Computed

  var providerType: AIRenamingProviderType {
    AIRenamingProviderType(rawValue: providerTypeRaw) ?? .openai
  }

  var preset: AIRenamingPreset {
    AIRenamingPreset(rawValue: presetRaw) ?? .descriptive
  }

  var openaiModel: OpenAIModel {
    OpenAIModel(rawValue: openaiModelRaw) ?? .gpt5Nano
  }

  // MARK: - API Key Management

  func apiKey(for provider: AIRenamingProviderType) -> String {
    KeychainHelper.shared.retrieve(for: "\(keychainKeyPrefix)\(provider.rawValue)") ?? ""
  }

  func saveAPIKey(_ key: String, for provider: AIRenamingProviderType) {
    if key.isEmpty {
      KeychainHelper.shared.delete("\(keychainKeyPrefix)\(provider.rawValue)")
    } else {
      KeychainHelper.shared.save(key, for: "\(keychainKeyPrefix)\(provider.rawValue)")
    }
  }

  // MARK: - Provider Factory

  func createProvider(for type: AIRenamingProviderType) -> AIRenamingProvider? {
    let key = apiKey(for: type)
    guard !key.isEmpty else { return nil }

    switch type {
    case .openai:
      return OpenAIRenamingProvider(apiKey: key, model: openaiModel)
    case .anthropic, .google:
      return nil // Not implemented yet
    }
  }

  // MARK: - Verify API Key

  func verifyAPIKey(for provider: AIRenamingProviderType) async {
    let key = apiKey(for: provider)
    guard !key.isEmpty else {
      await MainActor.run { keyVerificationResult = false }
      return
    }

    await MainActor.run {
      isVerifyingKey = true
      keyVerificationResult = nil
    }

    let result: Bool
    switch provider {
    case .openai:
      let openAI = OpenAIRenamingProvider(apiKey: key)
      result = await openAI.validateAPIKey(key)
    case .anthropic, .google:
      result = false
    }

    await MainActor.run {
      isVerifyingKey = false
      keyVerificationResult = result
    }
  }

  // MARK: - Rename File

  /// Renames a compressed file using AI. Returns the new URL or nil if renaming was skipped/failed.
  func renameFile(job: Job) async -> URL? {
    // C2 fix: Snapshot all @AppStorage settings on main thread to avoid data races
    let (enabled, currentPreset, currentCustomPrompt, currentMaxLength, currentProviderType) = await MainActor.run {
      (aiRenamingEnabled, preset, customPrompt, maxFilenameLength, providerType)
    }

    guard enabled, job.isImage, job.error == nil else { return nil }
    guard let provider = createProvider(for: currentProviderType) else { return nil }

    // H2 fix: Snapshot outputFileURL on main thread to avoid data race
    let outputURL = await MainActor.run {
      job.isAIRenaming = true
      JobManager.shared.objectWillChange.send()
      HUDJobManager.shared.objectWillChange.send()
      return job.outputFileURL
    }

    // C1 fix: Prepare image data on main thread (AppKit drawing APIs require it)
    guard let imageData = await MainActor.run(body: { prepareImageData(from: outputURL) }) else {
      await MainActor.run {
        job.isAIRenaming = false
        JobManager.shared.objectWillChange.send()
      HUDJobManager.shared.objectWillChange.send()
      }
      return nil
    }

    let result = await provider.generateName(
      imageData: imageData,
      mimeType: "image/jpeg",
      preset: currentPreset,
      customPrompt: currentPreset == .custom ? currentCustomPrompt : nil
    )

    guard let sanitizedName = result.sanitizedName else {
      await MainActor.run {
        job.isAIRenaming = false
        job.aiRenamingError = result.error
        JobManager.shared.objectWillChange.send()
      HUDJobManager.shared.objectWillChange.send()
      }
      return nil
    }

    let fileExtension = outputURL.pathExtension
    let directory = outputURL.deletingLastPathComponent()

    // Resolve potential collisions
    let finalName = AIRenamingFilenameSanitizer.resolveCollision(
      name: AIRenamingFilenameSanitizer.sanitize(sanitizedName, maxLength: currentMaxLength),
      extension: fileExtension,
      directory: directory
    )

    let newURL = directory.appendingPathComponent("\(finalName).\(fileExtension)")

    // H1 fix: Bail out if task was cancelled (e.g. user hit Stop) or file was deleted
    guard !Task.isCancelled,
          FileManager.default.fileExists(atPath: outputURL.path(percentEncoded: false)) else {
      await MainActor.run {
        job.isAIRenaming = false
        JobManager.shared.objectWillChange.send()
      HUDJobManager.shared.objectWillChange.send()
      }
      return nil
    }

    do {
      // Store original filename as xattr for undo support
      let originalName = outputURL.lastPathComponent
      try FileManager.default.moveItem(at: outputURL, to: newURL)
      setOriginalFilenameXattr(originalName, on: newURL)

      await MainActor.run {
        job.isAIRenaming = false
        job.outputFileURL = newURL
        job.aiRenamedName = finalName
        JobManager.shared.objectWillChange.send()
      HUDJobManager.shared.objectWillChange.send()
        updateClipboardIfNeeded()
      }
      return newURL
    } catch {
      await MainActor.run {
        job.isAIRenaming = false
        job.aiRenamingError = "Failed to rename: \(error.localizedDescription)"
        JobManager.shared.objectWillChange.send()
      HUDJobManager.shared.objectWillChange.send()
      }
      return nil
    }
  }

  // MARK: - Image Preparation

  private func prepareImageData(from url: URL) -> Data? {
    guard let image = NSImage(contentsOf: url) else { return nil }

    let maxDimension: CGFloat = 512
    let originalSize = image.size
    let scale: CGFloat

    if originalSize.width > maxDimension || originalSize.height > maxDimension {
      scale = min(maxDimension / originalSize.width, maxDimension / originalSize.height)
    } else {
      scale = 1.0
    }

    let newSize = NSSize(
      width: round(originalSize.width * scale),
      height: round(originalSize.height * scale)
    )

    let resizedImage = NSImage(size: newSize)
    resizedImage.lockFocus()
    image.draw(
      in: NSRect(origin: .zero, size: newSize),
      from: NSRect(origin: .zero, size: originalSize),
      operation: .copy,
      fraction: 1.0
    )
    resizedImage.unlockFocus()

    guard let tiffData = resizedImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
      return nil
    }

    return jpegData
  }

  // MARK: - Clipboard

  /// Re-writes clipboard with current output URLs after a successful rename.
  /// Must be called on MainActor.
  private func updateClipboardIfNeeded() {
    let shouldCopy = UserDefaults.standard.bool(forKey: "copyOutputFilesToClipboard")
    guard shouldCopy else { return }
    let urls = JobManager.shared.jobs.map { $0.outputFileURL }
    guard !urls.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects(urls as [NSPasteboardWriting])
  }

  // MARK: - Extended Attributes

  private func setOriginalFilenameXattr(_ name: String, on url: URL) {
    let attrName = "com.compresto.originalFilename"
    guard let data = name.data(using: .utf8) else { return }
    let path = url.path(percentEncoded: false)
    data.withUnsafeBytes { buffer in
      guard let pointer = buffer.baseAddress else { return }
      setxattr(path, attrName, pointer, data.count, 0, 0)
    }
  }
}
