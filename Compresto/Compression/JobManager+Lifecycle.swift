//
//  JobManager+Lifecycle.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 23/11/2023.
//

import Foundation
import SwiftUI
import IOKit.pwr_mgt
import DockProgress

extension JobManager {

  func terminate() {
    guard isRunning else { return }
    isTerminated = true
    if let process = currentProcess, process.isRunning {
      process.terminate()
      currentProcess = nil
    } else if let session = currentExportSession, session.status == .exporting || session.status == .waiting {
      session.cancelExport()
      currentExportSession = nil
    }
    if let job = currentJob {
      try? FileManager.default.removeItem(at: job.outputFileURL)
      // Clean up resized PNG temp file if exists
      if let resizedPNGTempURL = job.resizedPNGTempURL {
        try? FileManager.default.removeItem(at: resizedPNGTempURL)
      }
    }
    Task {
      await MainActor.run {
        if let index = jobs.firstIndex(where: { $0.id.uuidString == currentJob?.id.uuidString }) {
          jobs = Array(jobs[..<index])
        } else {
          jobs.removeAll()
        }
        isPaused = false
        isRunning = false
        shouldPause = false
        currentJob = nil
        currentIndex = nil
        DockProgress.progressInstance = nil
      }
    }
  }

  /// Pause compression after current file completes
  func pause() {
    guard isRunning, !isPaused else { return }
    shouldPause = true
  }

  /// Resume compression from next incomplete job
  func resume() async {
    guard isPaused else { return }

    // Find first incomplete job index
    guard let resumeIndex = jobs.firstIndex(where: {
      !FileManager.default.fileExists(atPath: $0.outputFileURL.path(percentEncoded: false))
    }) else {
      // All jobs complete - reset state
      await MainActor.run {
        isPaused = false
        isRunning = false
        shouldPause = false
        currentJob = nil
        currentIndex = nil
        DockProgress.progressInstance = nil
      }
      return
    }

    await MainActor.run {
      isPaused = false
      shouldPause = false
    }

    // Continue compression from resume point
    await compressFromIndex(resumeIndex)
  }

  func putComputerToSleepIfNeeded() {
    guard sleepWhenFinish else { return }
    DispatchQueue.main.async {
      let alert = NSAlert()
      alert.messageText = "Putting computer to sleep"
      alert.informativeText = "Your computer will go to sleep in 10 seconds."
      alert.alertStyle = .informational
      let sleepButton = alert.addButton(withTitle: "Sleep Now")
      alert.addButton(withTitle: "Cancel")

      var remaining = 10
      let timer = Timer(timeInterval: 1, repeats: true) { timer in
        remaining -= 1
        alert.informativeText = "Your computer will go to sleep in \(remaining) seconds."
        if remaining <= 0 {
          timer.invalidate()
          NSApp.stopModal(withCode: .alertFirstButtonReturn)
        }
      }
      RunLoop.main.add(timer, forMode: .modalPanel)

      let response = alert.runModal()
      timer.invalidate()

      if response == .alertFirstButtonReturn {
        let port = IOPMFindPowerManagement(mach_port_t(MACH_PORT_NULL))
        IOPMSleepSystem(port)
        IOServiceClose(port)
      }
    }
  }

  func sendPushNotificationIfNeeded() {
    let successCount = jobs.map { FileManager.default.fileExists(atPath: $0.outputFileURL.path(percentEncoded: false)) ? 1 : 0 }.reduce(0,+)
    if successCount > 0, let job = jobs.first {
      let path = job.outputFileURL.deletingLastPathComponent().path(percentEncoded: false)
      sendSuccessPushNotification(path: path, count: successCount, urls: jobs.map { $0.outputFileURL.absoluteString })
    } else if let error = jobs.first(where: { $0.error != nil })?.error {
      let hasPDFInput = jobs.contains { if case .pdfCompress = $0.outputType { return true }; return false }
      showCompressionFailedAlert(error: error, hasPDFInput: hasPDFInput)
    }
  }

  func copyEXIFData(job: Job) throws {
    let sourceURL = job.inputFileURL
    let destinationURL = job.outputFileURL
    guard let sourceImage = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
          let destinationImage = CGImageSourceCreateWithURL(destinationURL as CFURL, nil) else {
      throw NSError(domain: "com.example.EXIFCopy", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create image sources."])
    }

    let metadata = CGImageSourceCopyPropertiesAtIndex(sourceImage, 0, nil) as NSDictionary?

    guard let type = CGImageSourceGetType(destinationImage),
          let destinationImageDestination = CGImageDestinationCreateWithURL(destinationURL as CFURL, type, 1, nil) else {
      throw NSError(domain: "com.example.EXIFCopy", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create image destination."])
    }

    CGImageDestinationAddImageFromSource(destinationImageDestination, sourceImage, 0, metadata)
    if !CGImageDestinationFinalize(destinationImageDestination) {
      throw NSError(domain: "com.example.EXIFCopy", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize the image destination."])
    }
  }

  func copyIPTCData(job: Job) throws {
    let sourceURL = job.inputFileURL
    let destinationURL = job.outputFileURL
    guard let sourceImageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
          let destinationImageSource = CGImageSourceCreateWithURL(destinationURL as CFURL, nil) else {
      throw NSError(domain: "com.example.IPTCCopy", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create image sources"])
    }

    guard let sourceProperties = CGImageSourceCopyPropertiesAtIndex(sourceImageSource, 0, nil) as? [CFString: Any],
          var destinationProperties = CGImageSourceCopyPropertiesAtIndex(destinationImageSource, 0, nil) as? [CFString: Any] else {
      throw NSError(domain: "com.example.IPTCCopy", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to get image properties"])
    }

    if let sourceIPTCData = sourceProperties[kCGImagePropertyIPTCDictionary] as? [CFString: Any] {
      destinationProperties[kCGImagePropertyIPTCDictionary] = sourceIPTCData
    }

    guard let type = CGImageSourceGetType(destinationImageSource),
          let destinationImageDestination = CGImageDestinationCreateWithURL(destinationURL as CFURL, type, 1, nil) else {
      throw NSError(domain: "com.example.IPTCCopy", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to create image destination"])
    }

    CGImageDestinationAddImageFromSource(destinationImageDestination, destinationImageSource, 0, destinationProperties as CFDictionary)
    if !CGImageDestinationFinalize(destinationImageDestination) {
      throw NSError(domain: "com.example.IPTCCopy", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize the image destination"])
    }
  }

  /// Copies ICC color profile from source image to destination image
  func copyICCProfile(job: Job) throws {
    let sourceURL = job.inputFileURL
    let destinationURL = job.outputFileURL

    guard let sourceImageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
          let destinationImageSource = CGImageSourceCreateWithURL(destinationURL as CFURL, nil) else {
      throw NSError(domain: "com.compressx.ICCCopy", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create image sources"])
    }

    guard let sourceProperties = CGImageSourceCopyPropertiesAtIndex(sourceImageSource, 0, nil) as? [CFString: Any],
          var destinationProperties = CGImageSourceCopyPropertiesAtIndex(destinationImageSource, 0, nil) as? [CFString: Any] else {
      throw NSError(domain: "com.compressx.ICCCopy", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to get image properties"])
    }

    // Copy ICC profile name if present in source
    if let profileName = sourceProperties[kCGImagePropertyProfileName] {
      destinationProperties[kCGImagePropertyProfileName] = profileName
    } else {
      // No ICC profile in source, nothing to copy
      return
    }

    guard let type = CGImageSourceGetType(destinationImageSource),
          let destinationImageDestination = CGImageDestinationCreateWithURL(destinationURL as CFURL, type, 1, nil) else {
      throw NSError(domain: "com.compressx.ICCCopy", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to create image destination"])
    }

    CGImageDestinationAddImageFromSource(destinationImageDestination, destinationImageSource, 0, destinationProperties as CFDictionary)
    if !CGImageDestinationFinalize(destinationImageDestination) {
      throw NSError(domain: "com.compressx.ICCCopy", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize the image destination"])
    }
  }

  func copyFileTagIfNeeded(job: Job) {
    if let tagNames = try? job.inputFileURL.resourceValues(forKeys: [.tagNamesKey]) {
      try? job.outputFileURL.setResourceValues(tagNames)
    }
  }

  func removeFileIfNeeded(job: Job) {
    // Clean up resized PNG temp file (intermediate file from FFmpeg resize step)
    if let resizedPNGTempURL = job.resizedPNGTempURL {
      try? FileManager.default.removeItem(at: resizedPNGTempURL)
      job.resizedPNGTempURL = nil
    }
    if let tmpInputFileURL = job.tmpInputFileURL {
      try? FileManager.default.trashItem(at: job.inputFileURL, resultingItemURL: nil)
      job.inputFileURL = tmpInputFileURL
    }
    guard job.removeInputFile, let outputFileSize = job.outputFileSize, outputFileSize > 0, job.error == nil else {
      return
    }
    do {
      try FileManager.default.trashItem(at: job.inputFileURL, resultingItemURL: nil)
      if job.targetOutputURL.absoluteString != job.outputFileURL.absoluteString,
          !FileManager.default.fileExists(atPath: job.targetOutputURL.path(percentEncoded: false)) {
        try FileManager.default.moveItem(at: job.outputFileURL, to: job.targetOutputURL)
        job.outputFileURL = job.targetOutputURL
      }
    } catch {
    }
  }

  func setFileCreationIfNeeded(job: Job) {
    if retainCreationDate,
       let creationDate = job.inputFileCreationDate,
       var attributes = try? FileManager.default.attributesOfItem(atPath: job.outputFileURL.path(percentEncoded: false)) {
      attributes[.creationDate] = creationDate
      do {
        try FileManager.default.setAttributes(
          attributes,
          ofItemAtPath: job.outputFileURL.path(percentEncoded: false)
        )
      } catch {
      }
    }
  }

  #if !SETAPP
  func aiRenameIfNeeded(job: Job) {
    guard AIRenamingManager.shared.aiRenamingEnabled, job.error == nil else { return }
    Task { _ = await AIRenamingManager.shared.renameFile(job: job) }
  }
  #endif

  func queue(newJobs: [Job]) {
    for job in newJobs {
      if !jobs.contains(where: { $0.inputFileURL == job.inputFileURL }) {
        jobs.append(job)
      }
    }
    inputFileURLs = jobs.map { $0.inputFileURL }
  }
}
