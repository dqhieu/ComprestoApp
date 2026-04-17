//
//  JobManager.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 23/11/2023.
//

import Foundation
import SwiftUI
import AVFoundation
import IOKit.pwr_mgt
import TelemetryClient
import DockProgress
import SwiftDate
import Combine

/*
video:
  - transparency:
    - webm: ffmpeg
    - non-webm: apple
  - no transparency: ffmpeg
image:
  - png: pngquant
  - jpg: ffmpeg
gif:
  - gifski
*/

class JobManager: ObservableObject {

  @AppStorage("ffmpegPath") var ffmpegPath = ""
  @AppStorage("pngquantPath") var pngquantPath = ""
  @AppStorage("gifskiPath") var gifskiPath = ""
  @AppStorage("ghostscriptPath") var ghostscriptPath = ""
  @AppStorage("customOutputFolder") var customOutputFolder = ""
  @AppStorage("outputFolder") var outputFolder: OutputFolder = .same
  @AppStorage("videoCompressed") var videoCompressed: Int = 0
  @AppStorage("imageCompressed") var imageCompressed: Int = 0
  @AppStorage("gifConverted") var gifConverted: Int = 0
  @AppStorage("gifCompressed") var gifCompressed: Int = 0
  @AppStorage("pdfCompressed") var pdfCompressed: Int = 0
  @AppStorage("sizeReduced") var sizeReduced = 0
  @AppStorage("outputFileNameFormat") var outputFileNameFormat = ""
  @AppStorage("hardwareAccelerationEnabled") var hardwareAccelerationEnabled = false
  @AppStorage("compressionHistories") var compressionHistories: [CompressionHistory] = []
  @AppStorage("shouldSaveCompressionHistory") var shouldSaveCompressionHistory = true
  @AppStorage("retainCreationDate") var retainCreationDate = false
  @AppStorage("encodingCodec") var encodingCodec: Codec = .libx264
  @AppStorage("targetVideoFPS") var targetVideoFPS = TargetVideoFPS.same
  @AppStorage("retainImageMetadata") var retainImageMetadata = false
  @AppStorage("preserveColorProfile") var preserveColorProfile = false
  @AppStorage("copyOutputFilesToClipboard") var copyCompressedFilesToClipboard = false
  @AppStorage("confettiEnabled") var confettiEnabled = false
  @AppStorage("sleepWhenFinish") var sleepWhenFinish = false
  @AppStorage("imageSizeValue") var imageSizeValue = 100
  @AppStorage("nestedFolderName") var nestedFolderName = "compressed"
  @AppStorage("coreCount") var coreCount: CoreCount = .max

  @Published var isRunning = false
  @Published var inputFileURLs: [URL] = []
  @Published var jobs: [Job] = []
  @Published var currentIndex: Int?
  @Published var currentJob: Job?

  var currentIndexProgress: Int? {
    guard let index = currentIndex else { return nil }
    return Int(100 * Double(index - 1) / Double(jobs.count))
  }

  static let shared = JobManager()

  var currentExportSession: AVAssetExportSession?
  var currentProcess: Process?
  var isTerminated = false
  @Published var isPaused = false
  @Published var shouldPause = false
  @Published var currentProgress: Double = 0

  func createJobs(
    inputFileURLs: [URL],
    removeInputFile: Bool,
    imageQuality: ImageQuality,
    imageFormat: ImageFormat,
    imageSize: ImageSize,
    videoQuality: VideoQuality,
    videoDimension: VideoDimension,
    videoDimensionValue: Int,
    videoGifQuality: VideoQuality,
    videoGifDimension: GifDimension,
    gifQuality: VideoQuality,
    gifDimension: GifDimension,
    videoFormat: VideoFormat,
    targetFileSize: Double,
    pdfQuality: PDFQuality,
    hasAudio: Bool,
    removeAudio: Bool,
    fpsValue: Int,
    preserveTransparency: Bool,
    startTimes: [URL: CMTime],
    endTimes: [URL: CMTime]
  ) -> [Job] {
    let newJobs = inputFileURLs.map { url in

      let outputType: OutputType = {
        let fileType = checkFileType(url: url)
        switch fileType {
        case .image(let imageType):
          switch imageType {
          case .jpg:
            return .image(
              imageQuality: imageQuality,
              imageFormat: imageFormat,
              imageSize: imageSize,
              imageSizeValue: imageSizeValue
            )
          case .png:
            return .image(
              imageQuality: imageQuality,
              imageFormat: imageFormat,
              imageSize: imageSize,
              imageSizeValue: imageSizeValue
            )
          }
        case .video:
          if videoFormat == .gif {
            return .gif(
              gifQuality: videoGifQuality,
              fpsValue: fpsValue,
              dimension: videoGifDimension
            )
          } else {
            return .video(
              videoQuality: videoQuality,
              videoDimension: videoDimension,
              videoDimensionValue: videoDimensionValue,
              videoFormat: videoFormat,
              targetFileSize: targetFileSize,
              hasAudio: hasAudio,
              removeAudio: removeAudio,
              preserveTransparency: preserveTransparency,
              startTime: startTimes[url],
              endTime: endTimes[url]
            )
          }
        case .gif:
          return .gifCompress(
            gifQuality: gifQuality,
            dimension: gifDimension
          )
        case .pdf:
          return .pdfCompress(pdfQuality: pdfQuality)
        case .notSupported:
          fatalError()
        }
      }()
      return Job(
        inputFileURL: url,
        outputType: outputType,
        outputFolder: outputFolder,
        customOutputFolder: customOutputFolder,
        nestedFolderName: nestedFolderName,
        outputFileNameFormat: outputFileNameFormat,
        removeInputFile: removeInputFile
      )
    }
    return newJobs
  }

  func getJobIndex(_ job: Job) -> Int? {
    return jobs.firstIndex(where: { $0.id == job.id })
  }
}

class CommandlineHelper {
  static func run(process: Process) async -> String? {

    let commandLineTask = Task(priority: .utility) { () -> String? in
      do {
        try process.run()
        process.waitUntilExit()
        return nil
      } catch {
        return error.localizedDescription
      }
    }
    return await commandLineTask.value
  }

}

extension Collection {
  subscript (safe index: Index) -> Element? {
    return indices.contains(index) ? self[index] : nil
  }
}
