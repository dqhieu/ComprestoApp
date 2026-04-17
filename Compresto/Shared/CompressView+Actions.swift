//
//  CompressView+Actions.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 21/11/2023.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

extension CompressView {

  func handleOnDropFiles(urls: [URL]) {
    inputPaths = urls
    let maxDepth: Int = {
      switch subfolderProcessing {
      case .all:
        return 1_000
      case .none:
        return 1
      case .custom:
        return subfolderProcessingLimit
      }
    }()
    let files = flatten(urls: urls, maxDepth: maxDepth)
    onDropFiles(items: files)
  }

  func openFileSelectionPanel() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = true
    panel.canChooseFiles = true
    panel.showsHiddenFiles = true
    panel.allowedContentTypes = videoSupportedTypes + imageSupportedTypes + pdfSupportedTypes
    let response = panel.runModal()
    if response == .OK {
      let urls = panel.urls
      let maxDepth: Int = {
        switch subfolderProcessing {
        case .all:
          return 1_000
        case .none:
          return 1
        case .custom:
          return subfolderProcessingLimit
        }
      }()
      let files = flatten(urls: urls, maxDepth: maxDepth)
      inputPaths = urls
      setSourceFile(urls: files)
    }
  }

  func openFolderSelectionPanel() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    let response = panel.runModal()
    if response == .OK, let url = panel.url {
      customOutputFolder = url.path(percentEncoded: false)
    } else if customOutputFolder.isEmpty {
      outputFolder = .same
    }
  }

  func validateInputFile(urls: [URL]) -> [URL] {
    let supportedURLs = urls.filter { isFileSupported(url: $0) }

    hasImageInput = false
    hasVideoInput = false
    hasGifInput = false
    hasPDFInput = false
    imageCount = 0
    videoCount = 0
    gifCount = 0
    pdfCount = 0

    for url in supportedURLs {
      let fileType = checkFileType(url: url)
      switch fileType {
      case .image:
        hasImageInput = true
        imageCount += 1
      case .gif:
        hasGifInput = true
        gifCount += 1
      case .video:
        hasVideoInput = true
        videoCount += 1
      case .pdf:
        hasPDFInput = true
        pdfCount += 1
      case .notSupported:
        break
      }
    }

    return supportedURLs
  }

  func checkWebMFormat(urls: [URL]) {
    var hasAtleast1WebM = false
    for url in urls {
      if url.pathExtension.uppercased() == VideoFormat.webm.rawValue.uppercased() {
        hasAtleast1WebM = true
      }
    }
    isInputWebM = hasAtleast1WebM
    if isInputWebM {
      outputFormat = .same
    }
  }

  func checkAudio(urls: [URL]) {
    checkingAudioTrack = true
    Task {
      var hasAtleast1Audio = false
      for url in urls {
        let fileType = checkFileType(url: url)
        if fileType == .video {
          let inputHasAudio = await fileHasAudio(url: url)
          if inputHasAudio { hasAtleast1Audio = true }
        }
      }
      await MainActor.run {
        checkingAudioTrack = false
        hasAudio = hasAtleast1Audio
      }
    }
  }

  func checkTransparency(urls: [URL]) {
    showPreserveTransparency = false
    Task {
      var hasNoTransparency = true
      for url in urls {
        do {
          let hasTransparency = try await url.checkVideoTransparency
          if hasTransparency { hasNoTransparency = false }
        }
      }
      await MainActor.run {
        showPreserveTransparency = !hasNoTransparency
        if showPreserveTransparency {
          if outputFormat == .webm {
            shouldPreserveTransparency = true
          }
          if shouldPreserveTransparency {
            resetOptionForTransparencyIfNeeded()
          }
        } else {
          shouldPreserveTransparency = false
        }
      }
    }
  }

  func applyFileTypeFilter() {
    // Prevent unchecking all types — re-enable the one just toggled off
    if !filterImages && !filterVideos && !filterGifs && !filterPDFs {
      if imageCount > 0 { filterImages = true }
      else if videoCount > 0 { filterVideos = true }
      else if gifCount > 0 { filterGifs = true }
      else if pdfCount > 0 { filterPDFs = true }
      return // onChange will fire again from the re-enable
    }

    let filtered = allValidatedFiles.filter { url in
      let fileType = checkFileType(url: url)
      switch fileType {
      case .image: return filterImages
      case .gif: return filterGifs
      case .video: return filterVideos
      case .pdf: return filterPDFs
      case .notSupported: return false
      }
    }

    jobManager.inputFileURLs = filtered
    setInputFiles(urls: filtered)
    hasImageInput = filtered.contains { checkFileType(url: $0).isImage }
    hasVideoInput = filtered.contains { checkFileType(url: $0) == .video }
    hasGifInput = filtered.contains { checkFileType(url: $0) == .gif }
    hasPDFInput = filtered.contains { checkFileType(url: $0) == .pdf }
    checkWebMFormat(urls: filtered)
    checkAudio(urls: filtered)
    checkTransparency(urls: filtered)
  }

  func setSourceFile(urls: [URL]) {
    filterImages = true
    filterVideos = true
    filterGifs = true
    filterPDFs = true
    let filteredURLs = validateInputFile(urls: urls)
    allValidatedFiles = filteredURLs
    jobManager.inputFileURLs = filteredURLs
    setInputFiles(urls: filteredURLs)
    jobManager.jobs.removeAll()
    startTimes.removeAll()
    endTimes.removeAll()
    errorMessage = nil
    timeTaken = nil
    hasAudio = false
    reducedSizeString = nil
    removeFileError = nil
    showPreserveTransparency = false
    shouldPreserveTransparency = false
    shouldShowProductHuntLink = false
    checkWebMFormat(urls: filteredURLs)
    checkAudio(urls: filteredURLs)
    checkTransparency(urls: filteredURLs)
    if hasPDFInput && ghostscriptPath.isEmpty {
      showGhostscriptNotInstalledAlert()
    }
  }

  func setInputFiles(urls: [URL]) {
    inputFiles = urls.map { url -> InputFile in
      let fileType = checkFileType(url: url)
      return InputFile(
        fileType: fileType,
        url: url
      )
    }
    .filter { $0.fileType != .notSupported }
  }

  func resetOptionForTransparencyIfNeeded() {
    if !videoQualities.contains(videoQuality) {
      videoQuality = .highest
    }
    removeAudio = false
  }

  func compress(jobs: [Job]) {
    guard LicenseManager.shared.canCompress() else {
      return showActivateLicenseAlert()
    }
    errorMessage = nil
    for job in jobs {
      switch job.outputType {
      case .video(let videoQuality, let videoDimension, _, let videoFormat, _, _, let removeAudio, let preserveTransparency, _, _):
        self.videoQuality = videoQuality
        self.outputFormat = videoFormat
        self.removeAudio = removeAudio
        self.shouldPreserveTransparency = preserveTransparency
        self.videoDimension = videoDimension
      case .image(let imageQuality, let imageFormat, let imageSize, _):
        self.imageQuality = imageQuality
        self.outputImageFormat = imageFormat
        self.imageSize = imageSize
      case .gifCompress(let gifQuality, let dimension):
        self.gifQuality = gifQuality
        self.gifDimension = dimension
      case .gif(let gifQuality, let fpsValue, let dimension):
        self.videoGifQuality = gifQuality
        self.videoGifDimension = dimension
        self.fpsValue = Double(fpsValue)
      case .pdfCompress(let pdfQuality):
        self.pdfQuality = pdfQuality
      }
    }
    startDate = Date()
    commonCompress()
  }

  func compress() {
    guard LicenseManager.shared.canCompress() else {
      return showActivateLicenseAlert()
    }
    errorMessage = nil
    let jobs = jobManager.createJobs(
      inputFileURLs: jobManager.inputFileURLs,
      removeInputFile: removeFileAfterCompress,
      imageQuality: imageQuality,
      imageFormat: outputImageFormat,
      imageSize: imageSize,
      videoQuality: videoQuality,
      videoDimension: videoDimension,
      videoDimensionValue: videoDimensionValue,
      videoGifQuality: videoGifQuality,
      videoGifDimension: videoGifDimension,
      gifQuality: gifQuality,
      gifDimension: gifDimension,
      videoFormat: outputFormat,
      targetFileSize: targetFileSize,
      pdfQuality: pdfQuality,
      hasAudio: hasAudio,
      removeAudio: removeAudio,
      fpsValue: Int(fpsValue),
      preserveTransparency: shouldPreserveTransparency && showPreserveTransparency,
      startTimes: startTimes,
      endTimes: endTimes
    )
    jobManager.jobs = jobs
    startDate = Date()
    commonCompress()
  }

  func commonCompress() {
    Task {
      let jobs = await jobManager.compress()
      await MainActor.run {
        let totalTime = jobs.map { $0.totalTime }.reduce(0,+)
        timeTaken = totalTime.toString {
          $0.unitsStyle = .full
          $0.collapsesLargestUnit = false
          $0.allowsFractionalUnits = true
        }
        if !didOpenProductHuntLink, Int.random(in: 0...9) == 4 {
          shouldShowProductHuntLink = true
        } else {
          shouldShowProductHuntLink = false
        }
        if jobs.count > 1 {
          if outputFormat != .gif {
            let totalInputFileSize = jobs.map { $0.inputFileSize ?? 0 }.reduce(0,+)
            let totalOutputFileSize = jobs.map { $0.outputFileSize ?? 0 }.reduce(0,+)
            reducedSizeString = fileSizeString(from: totalInputFileSize - totalOutputFileSize)
          }
        } else if jobs.count == 1, let job = jobs.first {
          if let error = job.error {
          } else {
            if (job.inputFileSize ?? 0) - (job.outputFileSize ?? 0) <= 0 && outputFormat == .gif {
              reducedSizeString = nil
            } else {
              reducedSizeString = fileSizeString(from: (job.inputFileSize ?? 0) - (job.outputFileSize ?? 0))
            }
          }
        }
      }
    }
  }

  func onDropFiles(items: [URL]) {
    if jobManager.isRunning {
      let newJobs = jobManager.createJobs(
        inputFileURLs: items,
        removeInputFile: removeFileAfterCompress,
        imageQuality: imageQuality,
        imageFormat: outputImageFormat,
        imageSize: imageSize,
        videoQuality: videoQuality,
        videoDimension: videoDimension,
        videoDimensionValue: videoDimensionValue,
        videoGifQuality: videoGifQuality,
        videoGifDimension: videoGifDimension,
        gifQuality: gifQuality,
        gifDimension: gifDimension,
        videoFormat: outputFormat,
        targetFileSize: targetFileSize,
        pdfQuality: pdfQuality,
        hasAudio: hasAudio,
        removeAudio: removeAudio,
        fpsValue: Int(fpsValue),
        preserveTransparency: shouldPreserveTransparency && showPreserveTransparency,
        startTimes: startTimes,
        endTimes: endTimes
      )
      jobManager.queue(newJobs: newJobs)
      setInputFiles(urls: jobManager.inputFileURLs)
    } else {
      let optionKeyPressed = NSEvent.modifierFlags.contains(.option)
      switch onDropBehavior {
      case .replace:
        if optionKeyPressed {
          appendFiles(items: items)
        } else {
          replaceFiles(items: items)
        }
      case .append:
        if optionKeyPressed {
          replaceFiles(items: items)
        } else {
          appendFiles(items: items)
        }
      }
    }
  }

  func appendFiles(items: [URL]) {
    let currentFiles = jobManager.inputFileURLs
    let newFiles = items.filter { !currentFiles.contains($0) }
    setSourceFile(urls: currentFiles + newFiles)
  }

  func replaceFiles(items: [URL]) {
    setSourceFile(urls: items)
  }

  func showGhostscriptNotInstalledAlert() {
    let alert = NSAlert()
    alert.messageText = "Ghostscript is not installed"
    alert.informativeText = "Ghostscript is required for PDF compression. If you haven't set it up yet, check out our guide."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Open Guide")
    alert.addButton(withTitle: "Cancel")
    if alert.runModal() == .alertFirstButtonReturn {
      NSWorkspace.shared.open(URL(string: "https://compresto.app/docs/guides/getting-started/install-ghostscript")!)
    }
  }

  func showFileNotSupportedAlert(type: String) {
    let alert = NSAlert.init()
    alert.messageText = "The \(type) type is not supported!"
    alert.addButton(withTitle: "OK")
    let _ = alert.runModal()
  }

  func onMaxDepthSubmittion() {
    if let limit = Int(subfolderProcessingLimitText), limit > 0 {
      subfolderProcessingLimit = abs(limit)
    } else {
      let alert = NSAlert()
      alert.messageText = "Invalid value"
      alert.informativeText = "Value must be an positive integer"
      alert.addButton(withTitle: "OK")
      let _ = alert.runModal()
    }
  }

  func updateInputFiles(maxDepth: Int) {
    let files = flatten(urls: inputPaths, maxDepth: maxDepth)
    setSourceFile(urls: files)
  }
}
