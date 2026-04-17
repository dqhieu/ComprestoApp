//
//  VideoHelpers.swift
//  Compresto
//

import Foundation
import AVFoundation
import AppKit

func getFPS(from videoUrl: URL) async throws -> Float? {
  let asset = AVURLAsset(url: videoUrl)
  let track = try await asset.loadTracks(withMediaType: AVMediaType.video).first
  return try await track?.load(.nominalFrameRate)
}

func getVideoSize(from videoUrl: URL) async throws -> CGSize? {
  // Try AVURLAsset first
  let asset = AVURLAsset(url: videoUrl)
  if let track = try? await asset.loadTracks(withMediaType: AVMediaType.video).first,
     let size = try? await track.load(.naturalSize) {
    return size
  }

  // Fallback to FFmpeg
  let task = Process()
  task.launchPath = JobManager.shared.ffmpegPath
  task.arguments = [
    "-i",
    videoUrl.path(percentEncoded: false)
  ]

  let pipe = Pipe()
  task.standardError = pipe
  try task.run()

  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  if let output = String(data: data, encoding: .utf8) {
    // Parse FFmpeg output to find video dimensions
    let pattern = "Stream.*Video:.*?(\\d{2,})x(\\d{2,})"
    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
       let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)) {
      let widthRange = Range(match.range(at: 1), in: output)!
      let heightRange = Range(match.range(at: 2), in: output)!
      let width = Double(output[widthRange])!
      let height = Double(output[heightRange])!
      return CGSize(width: width, height: height)
    }
  }

  return nil
}

func getVideoDuration(from videoURL: URL) async throws -> TimeInterval {
  let asset = AVURLAsset(url: videoURL)
  var duration: CMTime = .zero
  do {
    duration = try await asset.load(.duration)
  } catch {
    // If loading duration fails initially, log it but proceed to FFmpeg fallback
    print("Warning: AVURLAsset failed to load duration: \(error.localizedDescription)")
  }

  let durationSeconds = CMTimeGetSeconds(duration)

  // If AVAsset duration is 0, try fallback with FFmpeg
  if durationSeconds == 0 || videoURL.pathExtension.lowercased() == "ts" || videoURL.pathExtension.lowercased() == "mts" {
    print("AVAsset duration is 0, attempting FFmpeg fallback for \(videoURL.lastPathComponent)")
    let task = Process()
    task.launchPath = JobManager.shared.ffmpegPath
    task.arguments = [
      "-i",
      videoURL.path(percentEncoded: false),
      "-hide_banner" // Add hide_banner to potentially simplify output
    ]

    let pipe = Pipe()
    task.standardError = pipe

    // Use a non-throwing try? and check for nil if run() fails
    guard let _ = try? task.run() else {
        print("Error: Failed to launch FFmpeg process.")
        return 0 // Return 0 if FFmpeg fails to start
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
      // Parse FFmpeg output to find the duration
      // Regex: Duration: HH:MM:SS.ms
      let pattern = "Duration: (\\d{2}):(\\d{2}):(\\d{2})\\.(\\d{2})"
      if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
        if let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)) {
          let hoursRange = Range(match.range(at: 1), in: output)!
          let minutesRange = Range(match.range(at: 2), in: output)!
          let secondsRange = Range(match.range(at: 3), in: output)!
          let fractionRange = Range(match.range(at: 4), in: output)!

          let hours = Double(output[hoursRange]) ?? 0
          let minutes = Double(output[minutesRange]) ?? 0
          let seconds = Double(output[secondsRange]) ?? 0
          let fraction = Double(output[fractionRange]) ?? 0

          // Calculate total seconds
          let totalSeconds = (hours * 3600) + (minutes * 60) + seconds + (fraction / pow(10, Double(output[fractionRange].count)))
          print("FFmpeg fallback successful. Duration: \(totalSeconds)s")
          return totalSeconds
        } else {
          print("Warning: Could not parse Duration from FFmpeg output.")
        }
      } else {
        print("Error: Invalid regex pattern for duration.")
      }
    } else {
      print("Warning: Could not read FFmpeg stderr output.")
    }
    // If FFmpeg fallback fails, return the original 0 duration
    return 0
  }

  // If AVAsset duration was non-zero, return it
  return durationSeconds
}

func getFFmpegParam(videoSize: CGSize, expectedDimension: VideoDimension, dimensionValue: Int = 1920) -> [String]? {
  switch expectedDimension {
  case .same:
    // For libx264, ensure dimensions are even
    let width = Int(videoSize.width)
    let height = Int(videoSize.height)
    if (width % 2 == 1 || height % 2 == 1) {
      return ["-filter:v", "scale=\(width - width % 2):\(height - height % 2)"]
    }
    return nil
  case .ultraHD:
    if videoSize.isFullHD || videoSize.isHD || videoSize.is4K {
      return nil
    }
    return ["-filter:v", "scale='trunc(oh*a/2)*2:2160'"]
  case .fullHD:
    if videoSize.isFullHD || videoSize.isHD {
      return nil
    }
    return ["-filter:v", "scale='trunc(oh*a/2)*2:1080'"]
  case .HD:
    if videoSize.isHD {
      return nil
    }
    return ["-filter:v", "scale='trunc(oh*a/2)*2:720'"]
  case .maxWidth:
    // Cap width at dimensionValue, no upscaling, round to even (libx264 requirement)
    return ["-filter:v", "scale='trunc(min(\(dimensionValue),iw)/2)*2:-2'"]
  case .maxHeight:
    // Cap height at dimensionValue, no upscaling, round to even (libx264 requirement)
    return ["-filter:v", "scale='-2:trunc(min(\(dimensionValue),ih)/2)*2'"]
  case .maxLongEdge:
    // Constrain the longer edge
    if videoSize.width >= videoSize.height {
      return getFFmpegParam(videoSize: videoSize, expectedDimension: .maxWidth, dimensionValue: dimensionValue)
    } else {
      return getFFmpegParam(videoSize: videoSize, expectedDimension: .maxHeight, dimensionValue: dimensionValue)
    }
  case .maxShortEdge:
    // Constrain the shorter edge
    if videoSize.width < videoSize.height {
      return getFFmpegParam(videoSize: videoSize, expectedDimension: .maxWidth, dimensionValue: dimensionValue)
    } else {
      return getFFmpegParam(videoSize: videoSize, expectedDimension: .maxHeight, dimensionValue: dimensionValue)
    }
  }
}

func getFFmpegParam(size: NSSize, imageSize: ImageSize, imageSizeValue: Int) -> [String]? {
  let newSize = getSize(
    inputWidth: size.width,
    inputHeight: size.height,
    imageSize: imageSize,
    imageSizeValue: imageSizeValue
  )
  return ["-vf", "scale=\(newSize.width):\(newSize.height)"]
}

func getVideoThumbnail(url: URL, cmTime: CMTime?) -> NSImage? {
  let asset = AVURLAsset(url: url)
  let imageGenerator = AVAssetImageGenerator(asset: asset)
  imageGenerator.appliesPreferredTrackTransform = true
  if let cgImage = try? imageGenerator.copyCGImage(at: cmTime ?? CMTime(seconds: 0, preferredTimescale: 1), actualTime: nil) {
    return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
  }
  return nil
}

func fileHasAudio(url: URL) async -> Bool {
  let asset = AVAsset(url: url)

  // Check if there are any audio tracks in the asset
  let audioTracks = try? await asset.loadTracks(withMediaType: .audio)

  // If AVAsset found audio tracks, return true
  if let tracks = audioTracks {
    return !tracks.isEmpty
  }

  // Fallback to FFmpeg for files like MKV where AVAsset might fail
  print("AVAsset found no audio tracks for \(url.lastPathComponent), attempting FFmpeg fallback")
  return await checkAudioWithFFmpeg(url: url)
}

func checkAudioWithFFmpeg(url: URL) async -> Bool {
  let task = Process()
  task.launchPath = JobManager.shared.ffmpegPath
  task.arguments = [
    "-i",
    url.path(percentEncoded: false),
    "-hide_banner",
    "-f", "null",
    "-"
  ]

  let pipe = Pipe()
  task.standardError = pipe

  guard let _ = try? task.run() else {
    print("Warning: Failed to launch FFmpeg process for audio detection")
    return false
  }

  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  if let output = String(data: data, encoding: .utf8) {
    // Parse FFmpeg output to find audio streams
    // Look for lines like "Stream #0:1(eng): Audio: aac (LC) (mp4a / 0x6134706D), 48000 Hz, stereo, fltp, 125 kb/s"
    let hasAudioStream = output.contains("Stream") && output.contains("Audio:")
    print("FFmpeg audio detection result for \(url.lastPathComponent): \(hasAudioStream)")
    return hasAudioStream
  }

  print("Warning: Could not read FFmpeg output for audio detection")
  return false
}

func numberOfAudioTracks(url: URL) async throws -> Int {
  let asset = AVAsset(url: url)

  // Get all audio tracks
  let audioTracks = try await asset.loadTracks(withMediaType: .audio)

  return audioTracks.count
}

func getVideoQualityParameters(videoQuality: VideoQuality, targetFileSize: Double, videoDuration: Double, audioSize: Int64?, fileSize: Int64?) -> ([String], String?) {
  let audioSizeInBits = Double(audioSize ?? 0) * 8 / 1024
  let targetFileSizeInBits = targetFileSize * 8 / 1024
  let fileSizeInKilobits = targetFileSizeInBits - audioSizeInBits
  let audioBitRate: String? = {
    if audioSize != nil {
      let bitRateInt = Int(Double(audioSizeInBits) / videoDuration)
      return "\(bitRateInt)k"
    }
    return nil
  }()
  if fileSizeInKilobits > 0, fileSizeInKilobits > audioSizeInBits * 2 {
    if videoQuality == .fileSize, videoDuration > 0, let fileSize = fileSize, targetFileSize < Double(fileSize) {
      // targetFileSize in bytes
      let bitrate = fileSizeInKilobits / videoDuration
      return ([
        "-b:v",
        "\(Int(bitrate))k"
      ], audioBitRate)
    } else {
      return ([
        "-crf",
        videoQuality.crf
      ], nil)
    }
  } else if targetFileSize > 0 {
    return getVideoQualityParameters(videoQuality: videoQuality, targetFileSize: targetFileSize, videoDuration: videoDuration, audioSize: (audioSize ?? 0) / 2, fileSize: fileSize)
  } else {
    return ([
      "-crf",
      videoQuality.crf
    ], nil)
  }
}

func getAudioSizeFrom(url: URL) async throws -> Int64 {
  var totalSize: Int64 = 0
  do {
    let asset = AVAsset(url: url)
    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
    for track in audioTracks {
      // load(.totalSampleDataLength) can sometimes fail or return 0
      if let audioSize = try? await track.load(.totalSampleDataLength) {
          totalSize += audioSize
      }
    }
  } catch {
     print("Warning: AVAsset failed to load audio tracks or size: \(error.localizedDescription)")
     // Proceed to FFmpeg fallback if AVAsset fails
     totalSize = 0
  }

  // If AVAsset size is 0, try fallback with FFmpeg
  if totalSize == 0 {
    print("AVAsset audio size is 0, attempting FFmpeg fallback for \(url.lastPathComponent)")

    // Get duration using the reliable function
    guard let duration = try? await getVideoDuration(from: url), duration > 0 else {
        print("Warning: Could not get valid duration for FFmpeg audio size calculation.")
        return 0
    }

    return Int64((128 * 1000 / 8.0) * duration)
  }

  // If AVAsset size was non-zero, return it
  print("AVAsset successful. Audio Size: \(fileSizeString(from: totalSize))")
  return totalSize
}
