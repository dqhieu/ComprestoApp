//
//  JobManager+Compress.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 23/11/2023.
//

import Foundation
import SwiftUI
import AVFoundation
import DockProgress
import TelemetryClient

extension JobManager {

  func createTask(job: Job) async -> (Process, String?) {
    let task = Process()
    var arguments: [String] = []
    var error: String?
    switch job.outputType {
    case .video(let videoQuality, let videoDimension, let videoDimensionValue, let videoFormat, let targetFileSize, let hasAudio, let removeAudio, _, let startTime, let endTime):
      // Handle MP3 audio extraction separately
      if videoFormat == .mp3 {
        guard hasAudio else {
          error = "Video has no audio track to extract"
          break
        }
        arguments.append(contentsOf: [
          "-y",
          "-i", job.inputFileURL.path(percentEncoded: false),
          "-vn",  // No video
          "-acodec", "libmp3lame",
          "-q:a", "0"  // Highest quality VBR
        ])
        // Handle trim if start/end times are set
        if let start = startTime, let end = endTime {
          arguments.insert(contentsOf: ["-ss", String(start.seconds)], at: 1)
          arguments.append(contentsOf: ["-t", String(end.seconds - start.seconds)])
        }
        arguments.append(job.outputFileURL.path(percentEncoded: false))
        task.launchPath = ffmpegPath
        if !isValidFFmpegPath(ffmpegPath) {
          error = "FFmpeg setting is not correct"
        }
        break
      }

      if hardwareAccelerationEnabled {
        arguments.append(contentsOf: [
          "-hwaccel",
          "auto"
        ])
      }
      arguments.append(contentsOf: [
        "-y",
        "-i",
        job.inputFileURL.path(percentEncoded: false)
      ])
      if coreCount != .max {
        arguments.append(contentsOf: [
          "-threads",
          coreCount.rawValue
        ])
      }
      let videoSize = try? await getVideoSize(from: job.inputFileURL)
      if let videoSize, let additionalParams = getFFmpegParam(videoSize: videoSize, expectedDimension: videoDimension, dimensionValue: videoDimensionValue) {
        arguments.append(contentsOf: additionalParams)
      }
      if let start = startTime, let end = endTime {
        if removeAudio || !hasAudio {
          arguments.append(contentsOf: [
            "-vf",
            "trim=start=\(start.seconds):end=\(end.seconds),setpts=PTS-STARTPTS"
          ])
        } else {
          let numberOfAudioTrack = (try? await numberOfAudioTracks(url: job.inputFileURL)) ?? 1
          if numberOfAudioTrack > 1 {
            var filterValue = "[0:v]trim=start=\(start.seconds):end=\(end.seconds),setpts=PTS-STARTPTS[v]"
            for i in 0..<numberOfAudioTrack {
              filterValue += ";[0:a\(i)]atrim=start=\(start.seconds):end=\(end.seconds),asetpts=PTS-STARTPTS[a\(i)]"
            }
            arguments.append(contentsOf: [
              "-filter_complex",
              filterValue,
              "-map",
              "[v]",
            ])
            for i in 0..<numberOfAudioTrack {
              arguments.append(contentsOf: [
                "-map",
                "[a\(i)]",
              ])
            }
          } else {
            arguments.append(contentsOf: [
              "-filter_complex",
              "[0:v]trim=start=\(start.seconds):end=\(end.seconds),setpts=PTS-STARTPTS[v];[0:a]atrim=start=\(start.seconds):end=\(end.seconds),asetpts=PTS-STARTPTS[a]",
              "-map",
              "[v]",
              "-map",
              "[a]",
            ])
          }
        }
      }
      let shouldUseWebMFormat: Bool = job.inputFileURL.pathExtension.uppercased() == VideoFormat.webm.rawValue.uppercased() || videoFormat == .webm
      let duration: TimeInterval = (try? await getVideoDuration(from: job.inputFileURL)) ?? 0
      let audioSize = try? await getAudioSizeFrom(url: job.inputFileURL)
      let fileSize = job.inputFileURL.fileSize
      let (videoQualityParameters, adjustedAudioSize) = getVideoQualityParameters(
        videoQuality: videoQuality,
        targetFileSize: targetFileSize,
        videoDuration: duration,
        audioSize: audioSize,
        fileSize: fileSize
      )
      if shouldUseWebMFormat {
        arguments.append(contentsOf: ["-c:v", "libvpx-vp9", "-b:v", "0"] + videoQualityParameters + ["-c:a", "libopus" ])
        if removeAudio && hasAudio {
          arguments.append(contentsOf: [
            "-an"
          ])
        } else {
          arguments.append(contentsOf: [
            "-c:a",
            "libopus"
          ])
        }
      } else {
        if targetVideoFPS != .same, let inputFPS = try? await getFPS(from: job.inputFileURL), targetVideoFPS.value < inputFPS {
          arguments.append(contentsOf: [
            "-r",
            targetVideoFPS.displayText
          ])
        }
        arguments.append(contentsOf: [
          "-c:v",
          encodingCodec.rawValue
        ])
        arguments.append(contentsOf: videoQualityParameters)
        if (removeAudio || !hasAudio) && !job.isFLV && !job.isAVI {
          arguments.append("-an")
        } else if job.isMKV && !job.isSameVideoOutput {
          arguments.append(contentsOf: [
            "-c:a",
            "aac",
            "-b:a",
            adjustedAudioSize ?? "128k"
          ])
        } else if startTime != nil && endTime != nil {

        } else if job.isFLV || job.isAVI || (job.isTS && job.isMP4Output) {
          arguments.append(contentsOf: [
            "-c:a",
            "aac",
            "-b:a",
            adjustedAudioSize ?? "128k"
          ])
        } else if !job.isFLV && !job.isAVI {
          if let adjustedAudioSize {
            arguments.append(contentsOf: [
              "-c:a",
              "aac",
              "-b:a",
              adjustedAudioSize
            ])
          } else {
            arguments.append(contentsOf: [
              "-c:a",
              "copy",
              "-map",
              "0:v:0",
              "-map",
              "0:a"
            ])
          }

        }
        switch encodingCodec {
        case .libx264:
          arguments.append(contentsOf: [
            "-pix_fmt",
            "yuv420p"
          ])
        case .libx265:
          arguments.append(contentsOf: [
            "-pix_fmt",
            "yuv420p",
            "-tag:v",
            "hvc1"
          ])
        }
      }
      arguments.append(job.outputFileURL.path(percentEncoded: false))
      task.launchPath = ffmpegPath
      if !isValidFFmpegPath(ffmpegPath) {
        error = "FFmpeg setting is not correct"
      }
    case .image(let imageQuality, let imageFormat, let imageSize, let imageSizeValue):
      let isPngInput = isPNGFile(url: job.inputFileURL)
      let isPngOutput = imageFormat == .same || imageFormat == .png
      if isPngInput && isPngOutput {
        // Use resized temp file if available (pngquant doesn't support resizing)
        let pngInputURL = job.resizedPNGTempURL ?? job.inputFileURL
        arguments.append(contentsOf: [
          pngInputURL.path(percentEncoded: false),
          "--quality",
          imageQuality.pngImageQualityLevel,
          "--force",
          "-o",
          job.outputFileURL.path(percentEncoded: false)
        ])
        task.launchPath = pngquantPath
        if !isValidPngquantPath(pngquantPath) {
          error = "pngquant setting is incorrect"
        }
      }
      else if imageFormat == .png {
        arguments.append(contentsOf: [
          "-y",
          "-i",
          job.inputFileURL.path(percentEncoded: false)
        ])
        if let imageRep = NSImageRep(contentsOf: job.inputFileURL), let additionalParams = getFFmpegParam(size: CGSize(width: imageRep.pixelsWide, height: imageRep.pixelsHigh), imageSize: imageSize, imageSizeValue: imageSizeValue) {
          arguments.append(contentsOf: additionalParams)
        }
        arguments.append(contentsOf: [
          "-compression_level",
          imageQuality.pngFFmpegQualityLevel,
          job.outputFileURL.path(percentEncoded: false)
        ])
        task.launchPath = ffmpegPath
        if !isValidFFmpegPath(ffmpegPath) {
          error = "FFmpeg setting is incorrect"
        }
      } else if imageFormat == .avif {
        arguments.append(contentsOf: [
          "-y",
          "-i",
          job.inputFileURL.path(percentEncoded: false)
        ])
        if let imageRep = NSImageRep(contentsOf: job.inputFileURL), let additionalParams = getFFmpegParam(size: CGSize(width: imageRep.pixelsWide, height: imageRep.pixelsHigh), imageSize: imageSize, imageSizeValue: imageSizeValue) {
          arguments.append(contentsOf: additionalParams)
        }
        if let inputImage = NSImage(contentsOf: job.inputFileURL), imageHasAlphaChannel(inputImage) {
          arguments.append(contentsOf: [
            "-map", "0", "-map", "0",
            "-filter:v:1", "alphaextract", "-frames:v", "1"
          ])
        }
        arguments.append(contentsOf: [
          "-c:v",
          "libaom-av1",
          "-still-picture",
          "1",
          "-crf",
          imageQuality.avifFFmpegQualityLevel,
          job.outputFileURL.path(percentEncoded: false)
        ])
        task.launchPath = ffmpegPath
        if !isValidFFmpegPath(ffmpegPath) {
          error = "FFmpeg setting is incorrect"
        }
      }
      else {
        // JPG output
        arguments.append(contentsOf: [
          "-y",
          "-i",
          job.inputFileURL.path(percentEncoded: false)
        ])
        // Build video filter: handle transparency (white bg) + optional scaling
        var filterComponents: [String] = []
        if let inputImage = NSImage(contentsOf: job.inputFileURL), imageHasAlphaChannel(inputImage) {
          // Replace transparent pixels with white background using geq filter
          filterComponents.append("geq=r='if(lte(alpha(X,Y),16),255,r(X,Y))':g='if(lte(alpha(X,Y),16),255,g(X,Y))':b='if(lte(alpha(X,Y),16),255,b(X,Y))'")
        }
        if let imageRep = NSImageRep(contentsOf: job.inputFileURL) {
          let newSize = getSize(inputWidth: CGFloat(imageRep.pixelsWide), inputHeight: CGFloat(imageRep.pixelsHigh), imageSize: imageSize, imageSizeValue: imageSizeValue)
          filterComponents.append("scale=\(Int(newSize.width)):\(Int(newSize.height))")
        }
        if !filterComponents.isEmpty {
          arguments.append(contentsOf: ["-vf", filterComponents.joined(separator: ",")])
        }
        arguments.append(contentsOf: [
          "-q:v",
          imageQuality.jpgImageQualityLevel,
          job.outputFileURL.path(percentEncoded: false)
        ])
        task.launchPath = ffmpegPath
        if !isValidFFmpegPath(ffmpegPath) {
          error = "FFmpeg setting is incorrect"
        }
      }
    case .gif(let gifQuality, let fpsValue, let dimension):
      if let videoSize = try? await getVideoSize(from: job.inputFileURL) {
        let width = String(Int(videoSize.width * dimension.fraction))
        arguments.append(contentsOf: [
          "--width",
          width
        ])
      }
      var targetFps: Int = fpsValue
      let videoFps = try? await getFPS(from: job.inputFileURL)
      if let fps = videoFps, targetFps > Int(fps) {
        targetFps = Int(fps)
      }
      arguments.append(contentsOf: [
        "--fps",
        "\(targetFps)",
        "--quality",
        gifQuality.gifQualityLevel,
        "-o",
        job.outputFileURL.path(percentEncoded: false),
        job.inputFileURL.path(percentEncoded: false)
      ])
      task.launchPath = gifskiPath
      if !isValidGifskiPath(gifskiPath) {
        error = "gifski setting is incorrect"
      }
    case .gifCompress(let gifQuality, let dimension):
      if let imageRep = NSImageRep(contentsOf: job.inputFileURL) {
        let width = String(Int(Double(imageRep.pixelsWide) * dimension.fraction))
        arguments.append(contentsOf: [
          "--width",
          width
        ])
      }
      let videoFps = (try? await getFPS(from: job.inputFileURL)) ?? 20
      let targetFps = Int(videoFps)
      arguments.append(contentsOf: [
        "--fps",
        "\(targetFps)",
        "--quality",
        gifQuality.gifQualityLevel,
        "-o",
        job.outputFileURL.path(percentEncoded: false),
        job.inputFileURL.path(percentEncoded: false)
      ])
      task.launchPath = gifskiPath
      if !isValidGifskiPath(gifskiPath) {
        error = "gifski setting is incorrect"
      }
    case .pdfCompress(let pdfQuality):
      arguments.append(contentsOf: [
        "-sDEVICE=pdfwrite",
        "-dCompatibilityLevel=1.7",
        "-dPDFSETTINGS=/\(pdfQuality.paramValue)",
        "-dNOPAUSE",
        "-dBATCH",
        "-dAutoRotatePages=/None",
        "-dColorImageDownsampleType=/Bicubic",
        "-dGrayImageDownsampleType=/Bicubic",
        "-dNOTRANSPARENCY",
        "-sOutputFile=\(job.outputFileURL.path(percentEncoded: false))",
        job.inputFileURL.path(percentEncoded: false)
      ])
      task.launchPath = ghostscriptPath
    }
    task.arguments = arguments
    return (task, error)
  }

  /// Resizes a PNG image using FFmpeg to a temporary file.
  /// Returns the temp file URL on success, nil if no resize needed or on error.
  func resizePNGWithFFmpeg(inputURL: URL, imageSize: ImageSize, imageSizeValue: Int) async -> URL? {
    guard imageSize != .same else { return nil }
    guard let imageRep = NSImageRep(contentsOf: inputURL) else { return nil }

    let tempDir = FileManager.default.temporaryDirectory
    let tempFileName = UUID().uuidString + ".png"
    let tempURL = tempDir.appendingPathComponent(tempFileName)

    let newSize = getSize(
      inputWidth: CGFloat(imageRep.pixelsWide),
      inputHeight: CGFloat(imageRep.pixelsHigh),
      imageSize: imageSize,
      imageSizeValue: imageSizeValue
    )

    // Skip resize if dimensions unchanged
    if Int(newSize.width) == imageRep.pixelsWide && Int(newSize.height) == imageRep.pixelsHigh {
      return nil
    }

    let process = Process()
    process.launchPath = ffmpegPath
    process.arguments = [
      "-y",
      "-i", inputURL.path(percentEncoded: false),
      "-vf", "scale=\(Int(newSize.width)):\(Int(newSize.height))",
      tempURL.path(percentEncoded: false)
    ]

    let error = await CommandlineHelper.run(process: process)
    if error != nil {
      try? FileManager.default.removeItem(at: tempURL)
      return nil
    }

    return tempURL
  }

  func transcodeVideo(sourceFileURL: URL, outputFileURL: URL, videoQuality: VideoQuality, startTime: CMTime?, endTime: CMTime?) async -> String? {
    let avAsset = AVURLAsset(url: sourceFileURL)
    guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: videoQuality.avAssetExportPresetName) else {
      return "Unable to create AVAssetExportSession"
    }
    exportSession.outputURL = outputFileURL
    exportSession.outputFileType = .mp4
    exportSession.shouldOptimizeForNetworkUse = true

    await exportSession.export()
    return exportSession.error?.localizedDescription
  }

  func compress(job: Job, isRetrying: Bool = false) async -> String? {
    if case .video(let videoQuality, _, _, let videoFormat, _, _, _, let preserveTransparency, let startTime, let endTime) = job.outputType, preserveTransparency && videoFormat != .webm {
      return await transcodeVideo(sourceFileURL: job.inputFileURL, outputFileURL: job.outputFileURL, videoQuality: videoQuality, startTime: startTime, endTime: endTime)
    }
    guard isFileSupported(url: job.inputFileURL) else {
      return "File format is not supported"
    }
    guard FileManager.default.fileExists(atPath: job.inputFileURL.path(percentEncoded: false)) else {
      return "Input file does not exist"
    }
    if case .image(let imageQuality, let imageFormat, let imageSize, let imageSizeValue) = job.outputType, (imageFormat == .webp || imageFormat == .same && job.isWebP) {
      return WebPCoder.shared.convert(
        inputURL: job.inputFileURL,
        outputURL: job.outputFileURL,
        imageQuality: imageQuality,
        imageSize: imageSize,
        imageSizeValue: imageSizeValue
      )
    }
    if case .image(let imageQuality, let imageFormat, let imageSize, let imageSizeValue) = job.outputType, isSVGFile(url: job.inputFileURL) {
      return SVGProcessor.convert(job: job, imageQuality: imageQuality, imageFormat: imageFormat, imageSize: imageSize, imageSizeValue: imageSizeValue)
    }
    if case .image(let imageQuality, let imageFormat, let imageSize, let imageSizeValue) = job.outputType, isSVGFile(url: job.inputFileURL), isTiffFile(url: job.inputFileURL), imageFormat == .same {
      return TIFFProcessor.compress(job: job, imageQuality: imageQuality, imageFormat: imageFormat, imageSize: imageSize, imageSizeValue: imageSizeValue)
    }
    if case .pdfCompress = job.outputType, ghostscriptPath.isEmpty {
      return "Ghostscript is not installed"
    }
    // PNG resize step: pngquant doesn't support resizing, so use FFmpeg first
    if case .image(_, let imageFormat, let imageSize, let imageSizeValue) = job.outputType {
      let isPngInput = isPNGFile(url: job.inputFileURL)
      let isPngOutput = imageFormat == .same || imageFormat == .png
      if isPngInput && isPngOutput && imageSize != .same {
        if let resizedURL = await resizePNGWithFFmpeg(
          inputURL: job.inputFileURL,
          imageSize: imageSize,
          imageSizeValue: imageSizeValue
        ) {
          job.resizedPNGTempURL = resizedURL
        }
      }
    }
    let (process, pathError) = await createTask(job: job)
    currentProcess = process
    if !job.isProgressNotAvailable {
      // TODO: if input file is MKV, then process doesn't emit any output
      catchProgress(job: job, process: process)
    }
    if isRetrying {
      job.status = "Retrying"
    } else {
      if job.isProgressNotAvailable {
        job.status = "Compressing"
      } else if job.isVideo {
        job.status = "Preparing"
      } else if job.isGif {
        job.status = "Converting"
      } else {
        job.status = "Compressing"
      }
    }
    let error = await CommandlineHelper.run(process: process)
    job.status = "Finished"
    currentProcess = nil
    if error == nil {
      switch job.outputType {
      case .video(let videoQuality, let videoDimension, let videoDimensionValue, let videoFormat, let targetFileSize, let hasAudio, let removeAudio, let preserveTransparency, let startTime, let endTime):
        if FileManager.default.fileExists(atPath: job.outputFileURL.path(percentEncoded: false)),
           (job.outputFileSize ?? 0) >= (job.inputFileSize ?? 0),
           videoQuality != .fileSize,
           let nextQuality = videoQuality.next {
          let newOutputType = OutputType.video(
            videoQuality: nextQuality,
            videoDimension: videoDimension,
            videoDimensionValue: videoDimensionValue,
            videoFormat: videoFormat,
            targetFileSize: targetFileSize,
            hasAudio: hasAudio,
            removeAudio: removeAudio,
            preserveTransparency: preserveTransparency,
            startTime: startTime,
            endTime: endTime
          )
          job.outputType = newOutputType
          job.outputFileURL.removeCachedResourceValue(forKey: URLResourceKey.fileSizeKey)
          try? FileManager.default.removeItem(at: job.outputFileURL)
          return await compress(job: job, isRetrying: true)
        }
      case .gifCompress(let gifQuality, let dimension):
        if FileManager.default.fileExists(atPath: job.outputFileURL.path(percentEncoded: false)),
           (job.outputFileSize ?? 0) >= (job.inputFileSize ?? 0),
           let nextQuality = gifQuality.next {
          let newOutputType = OutputType.gifCompress(
            gifQuality: nextQuality,
            dimension: dimension
          )
          job.outputType = newOutputType
          job.outputFileURL.removeCachedResourceValue(forKey: URLResourceKey.fileSizeKey)
          try? FileManager.default.removeItem(at: job.outputFileURL)
          return await compress(job: job, isRetrying: true)
        }
      default:
        break
      }
    }
    return pathError ?? error
  }

  func catchProgress(job: Job, process: Process) {
    DispatchQueue.main.async { [weak self] in
      if job.isVideo || job.isGif {
        self?.currentProgress = 0
      }
    }
    let pipe = Pipe()
    if job.isVideo {
      process.standardError = pipe
    } else if job.isGif {
      process.standardOutput = pipe
    }
    Task {
      let duration: TimeInterval = (try? await getVideoDuration(from: job.inputFileURL)) ?? 0
      guard duration > 1 else { return }
      pipe.fileHandleForReading.readabilityHandler = { [weak self] (fileHandle) -> Void in
        let availableData = fileHandle.availableData
        var newProgress: Double?
        if let newOutput = String.init(data: availableData, encoding: .utf8) {
          let split = newOutput.split(separator: " ")
          if job.isVideo, let timeInfo = split.first(where: { $0.hasPrefix("time=") }), let time = String(timeInfo).toTimeInterval() {
            let adjustedDuration: Double = {
              if let start = job.outputType.startTime, let end = job.outputType.endTime {
                return min(end - start, duration)
              }
              return duration
            }()
            newProgress = Double(time / adjustedDuration)
          } else if job.isGif {
            let dotCount = newOutput.filter { $0 == "." }.count
            let hashCount = newOutput.filter { $0 == "#" }.count
            newProgress = Double(hashCount) / Double(hashCount + dotCount)
          }
        }
        if let progress = newProgress {
          DispatchQueue.main.async { [weak self] in
            self?.currentProgress = min(max(0, progress), 1)
            if job.isVideo {
              job.status = "Compressing"
            } else if job.isGif, progress > 0.01 {
              job.status = "Converting"
            } else if progress >= 1 {
              job.status = "Finalizing"
            }
            DockProgress.progress = min(max(0, progress), 1)
          }
        }
      }
    }
  }

  func compress() async -> [Job] {
    await MainActor.run {
      DockProgress.resetProgress()
      if copyCompressedFilesToClipboard {
        NSPasteboard.general.clearContents()
      }
    }
    await compressFromIndex(0)
    return self.jobs
  }

  func compressFromIndex(_ startIndex: Int) async {
    NoSleep.disableSleep()
    await MainActor.run {
      isRunning = true
      isTerminated = false
    }

    var i = startIndex
    while let job = jobs[safe: i] {
      if isTerminated { break }
      let index = i

      await MainActor.run {
        currentJob = job
        if jobs.count == 1 {
          DockProgress.style = .pie(color: .blue)
        } else {
          DockProgress.style = .badge(color: .blue, badgeValue: { [jobs] in
            jobs.count - index
          })
        }
        if !job.isVideo {
          DockProgress.progress = (Double(index) + 0.01) / Double(jobs.count)
        }
        currentIndex = index + 1
      }
      if shouldPause || isPaused {
        await MainActor.run {
          isPaused = true
          shouldPause = false
        }
        break
      }
      let startDate = Date()
      let error = await compress(job: job)
      job.error = error
      job.totalTime = abs(startDate.timeIntervalSinceNow)
      if job.isImage && retainImageMetadata {
        try? copyEXIFData(job: job)
        try? copyIPTCData(job: job)
      }
      if job.isImage && preserveColorProfile {
        try? copyICCProfile(job: job)
      }
      copyFileTagIfNeeded(job: job)
      removeFileIfNeeded(job: job)
      trackFinishJob(job)
      setFileCreationIfNeeded(job: job)
      #if !SETAPP
      aiRenameIfNeeded(job: job)
      #endif

      i += 1
      if index >= jobs.count { break }
    }

    await MainActor.run {
      if !isTerminated && !isPaused {
        currentJob = nil
        currentIndex = nil
      }
      if !isPaused {
        isRunning = false
        DockProgress.progressInstance = nil
        let outputFileURLs = jobs.map { $0.outputFileURL }
        if copyCompressedFilesToClipboard, !outputFileURLs.isEmpty {
          NSPasteboard.general.writeObjects(outputFileURLs as [NSPasteboardWriting])
        }
        let successCount = jobs.map { FileManager.default.fileExists(atPath: $0.outputFileURL.path(percentEncoded: false)) ? 1 : 0 }.reduce(0,+)
        if confettiEnabled, successCount > 0, let url = URL(string: "raycast://confetti") {
          NSWorkspace.shared.open(url)
        }
        sendPushNotificationIfNeeded()
        putComputerToSleepIfNeeded()
      }
    }
    NoSleep.enableSleep()
  }

  func trackFinishJob(_ job: Job) {
    if let error = job.error {
      TelemetryDeck.signal("compress.error", parameters: [
        "error": String(describing: error),
        "inputFileSize": String(job.inputFileSize ?? 0),
        "inputFileSizeString": fileSizeString(from: job.inputFileSize),
        "inputFileFormat": job.inputFileURL.pathExtension,
      ])
    } else if let outputFileSize = job.outputFileSize, outputFileSize > 0 {
      let fileSizeReduced = (job.inputFileSize ?? 0) - outputFileSize
      let trackingData: [String: String] = [
        "inputFileSize": String(job.inputFileSize ?? 0),
        "inputFileSizeString": fileSizeString(from: job.inputFileSize),
        "inputFileFormat": job.inputFileURL.pathExtension,
        "outputFileSize": String(outputFileSize),
        "outputFileSizeString": fileSizeString(from: outputFileSize),
        "outputFileFormat": job.outputFileURL.pathExtension,
        "reducedSize": String((job.inputFileSize ?? 0) - outputFileSize),
        "reducedSizeString": fileSizeString(from: fileSizeReduced),
        "totalTime": String(job.totalTime),
        "hardwareAccelerationEnabled": String(hardwareAccelerationEnabled)
      ]
      let inputSize = Double(job.inputFileSize ?? 1)
      let history = CompressionHistory(
        fileName: job.outputFileURL.path(percentEncoded: false),
        originalSize: fileSizeString(from: job.inputFileSize),
        compressedSize: fileSizeString(from: outputFileSize),
        reducedSize: fileSizeString(from: fileSizeReduced),
        timeTaken: Int(ceil(job.totalTime)).seconds.timeInterval.toString {
          $0.unitsStyle = .full
          $0.collapsesLargestUnit = false
          $0.allowsFractionalUnits = true
        },
        reducePercentage: Double(fileSizeReduced) / inputSize
      )
      Task {
        await MainActor.run {
          if fileSizeReduced > 0 {
            sizeReduced += Int(fileSizeReduced)
          }
          switch job.outputType {
          case .video(_, _, _, let videoFormat, _, _, _, _, _, _):
            if videoFormat == .mp3 {
              // Track as conversion, not compression
              TelemetryDeck.signal("convert.finish.mp3", parameters: trackingData)
            } else {
              videoCompressed += 1
              TelemetryDeck.signal("compress.finish", parameters: trackingData)
              if shouldSaveCompressionHistory {
                compressionHistories.append(history)
              }
            }
          case .image:
            imageCompressed += 1
            TelemetryDeck.signal("compress.finish", parameters: trackingData)
            if shouldSaveCompressionHistory {
              compressionHistories.append(history)
            }
          case .gifCompress:
            gifCompressed += 1
            TelemetryDeck.signal("compress.finish", parameters: trackingData)
            if shouldSaveCompressionHistory {
              compressionHistories.append(history)
            }
          case .gif:
            gifConverted += 1
            TelemetryDeck.signal("convert.finish.gif", parameters: trackingData)
          case .pdfCompress:
            pdfCompressed += 1
            TelemetryDeck.signal("compress.finish", parameters: trackingData)
            if shouldSaveCompressionHistory {
              compressionHistories.append(history)
            }
          }
        }
      }
    }
  }
}
