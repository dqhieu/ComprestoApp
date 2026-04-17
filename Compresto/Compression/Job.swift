//
//  Job.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 23/11/2023.
//

import Foundation
import SwiftUI
import AVFoundation

struct CompressionHistory: Codable, Identifiable, Hashable {
  var id = UUID().uuidString
  var fileName: String
  var originalSize: String
  var compressedSize: String
  var reducedSize: String
  var timeTaken: String
  var reducePercentage: Double
}

enum OutputType {
  case video(
    videoQuality: VideoQuality,
    videoDimension: VideoDimension,
    videoDimensionValue: Int,
    videoFormat: VideoFormat,
    targetFileSize: Double,
    hasAudio: Bool,
    removeAudio: Bool,
    preserveTransparency: Bool,
    startTime: CMTime?,
    endTime: CMTime?
  )
  case image(imageQuality: ImageQuality, imageFormat: ImageFormat, imageSize: ImageSize, imageSizeValue: Int)
  case gif(gifQuality: VideoQuality, fpsValue: Int, dimension: GifDimension)
  case gifCompress(gifQuality: VideoQuality, dimension: GifDimension)
  case pdfCompress(pdfQuality: PDFQuality)

  var startTime: Double? {
    switch self {
    case .video(_, _, _, _, _, _, _, _, let startTime, _):
      return startTime?.seconds
    default: return nil
    }
  }

  var endTime: Double? {
    switch self {
    case .video(_, _, _, _, _, _, _, _, _, let endTime):
      return endTime?.seconds
    default: return nil
    }
  }
}

class Job: Identifiable {

  var id = UUID()

  var outputType: OutputType
  var inputFileURL: URL
  let inputFileSize: Int64?
  var outputFileURL: URL
  let removeInputFile: Bool
  let inputFileCreationDate: Date?

  var error: String?
  var totalTime: TimeInterval = 0

  var outputFileSize: Int64? {
    return outputFileURL.fileSize
  }

  var status: String = ""

  var targetOutputURL: URL
  var originalOutputURL: URL

  var isAIRenaming = false
  var aiRenamedName: String?
  var aiRenamingError: String?

  var tmpInputFileURL: URL?
  var resizedPNGTempURL: URL?  // Temp file for PNG resize step (FFmpeg → pngquant)

  var reducedPercentage: String? {
    if let inputSize = inputFileSize, let outputSize = outputFileSize, outputSize < inputSize {
      let percentage = Double(outputSize) / Double(inputSize) * 100
      let percentageInt = Int(100 - percentage)
      return "\(percentageInt)%"
    }
    return nil
  }

  init(
    inputFileURL: URL,
    outputType: OutputType,
    outputFolder: OutputFolder,
    customOutputFolder: String,
    nestedFolderName: String,
    outputFileNameFormat: String,
    removeInputFile: Bool
  ) {
    self.inputFileURL = inputFileURL
    self.inputFileSize = inputFileURL.fileSize
    self.outputType = outputType
    self.removeInputFile = removeInputFile
    self.inputFileCreationDate = try? getFileCreationDate(from: inputFileURL)
    let outputFolderURL: URL = {
      switch outputFolder {
      case .same:
        return inputFileURL.deletingLastPathComponent()
      case .nested:
        var path = inputFileURL.deletingLastPathComponent()
        if nestedFolderName.isEmpty {
          path.appendPathComponent("compressed")
        } else {
          path.appendPathComponent(nestedFolderName)
        }
        if FileManager.default.fileExists(atPath: path.path(percentEncoded: false)) == false {
          try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        }
        return path
      case .custom:
        if !customOutputFolder.isEmpty {
          return URL(string: "file://" + customOutputFolder)!
        }
        return inputFileURL.deletingLastPathComponent()
      }
    }()
    let qualityText: String = {
      switch outputType {
      case .video(let videoQuality, _, _, _, _, _, _, _, _, _):
        return videoQuality.displayText
      case .image(let imageQuality, _, _, _):
        return imageQuality.displayText
      case .gif(let gifQuality, _, _):
        return gifQuality.displayText
      case .gifCompress(let gifQuality, _):
        return gifQuality.displayText
      case .pdfCompress(let pdfQuality):
        return pdfQuality.displayText
      }
    }()
    let resolutionText: String = {
      switch outputType {
      case .video(_, let videoDimension, _, _, _, _, _, _, _, _):
        return videoDimension.rawValue
      case .image(_, _, let imageSize, _):
        return imageSize.rawValue
      case .gif(_, _, let dimension):
        return dimension.rawValue
      case .gifCompress(_, let dimension):
        return dimension.rawValue
      case .pdfCompress:
        return ""
      }
    }()
    let intputFileNameWithoutExtension = inputFileURL.deletingPathExtension().lastPathComponent
    let format = outputFileNameFormat
      .replacingOccurrences(of: "{timestamp}", with: "\(Int(Date.now.timeIntervalSince1970))")
      .replacingOccurrences(of: "{datetime}", with: Date().toISO8601DateTime)
      .replacingOccurrences(of: "{date}", with: Date().toISO8601Date)
      .replacingOccurrences(of: "{time}", with: Date().toISO8601Time)
      .replacingOccurrences(of: "{quality}", with: qualityText)
      .replacingOccurrences(of: "{resolution}", with: resolutionText)

    switch outputType {
    case .video(_, _, _, let videoFormat, _, _, _, _, _, _):
      if videoFormat == .mp3 {
        // MP3 audio extraction output
        outputFileURL = outputFolderURL.appendingPathComponent(intputFileNameWithoutExtension + format + ".mp3")
      } else if videoFormat != .same {
        outputFileURL = outputFolderURL.appendingPathComponent(intputFileNameWithoutExtension + format + "." + videoFormat.rawValue)
      } else {
        outputFileURL = outputFolderURL.appendingPathComponent(intputFileNameWithoutExtension + format + "." + inputFileURL.pathExtension)
      }
    case .image(_, let imageFormat, _, _):
      if isRawImage(url: inputFileURL), let url = preProcessRawImage(inputFileURL: inputFileURL) {
        self.tmpInputFileURL = inputFileURL
        self.inputFileURL = url
      }
      switch imageFormat {
      case .same:
        if isPNGFile(url: self.inputFileURL) {
          outputFileURL = outputFolderURL.appendingPathComponent(intputFileNameWithoutExtension + format + ".png")
        } else if isSVGFile(url: self.inputFileURL) {
          outputFileURL = outputFolderURL.appendingPathComponent(intputFileNameWithoutExtension + format + ".svg")
        } else if isTiffFile(url: self.inputFileURL) {
          outputFileURL = outputFolderURL.appendingPathComponent(intputFileNameWithoutExtension + format + ".tif")
        } else {
          outputFileURL = outputFolderURL.appendingPathComponent(intputFileNameWithoutExtension + format + ".jpg")
        }
      case .webp:
        outputFileURL = outputFolderURL.appendingPathComponent(intputFileNameWithoutExtension + format + ".webp")
      case .jpg:
        outputFileURL = outputFolderURL.appendingPathComponent(intputFileNameWithoutExtension + format + ".jpg")
      case .png:
        outputFileURL = outputFolderURL.appendingPathComponent(intputFileNameWithoutExtension + format + ".png")
      case .avif:
        outputFileURL = outputFolderURL.appendingPathComponent(intputFileNameWithoutExtension + format + ".avif")
      }
    case .gif, .gifCompress:
      outputFileURL = outputFolderURL.appendingPathComponent(intputFileNameWithoutExtension + format + ".gif")
    case .pdfCompress:
      outputFileURL = outputFolderURL.appendingPathComponent(intputFileNameWithoutExtension + format + ".pdf")
    }

    targetOutputURL = outputFileURL
    var count = 1
    while FileManager.default.fileExists(atPath: outputFileURL.path(percentEncoded: false)) {
      let fileExtension = outputFileURL.pathExtension
      outputFileURL = outputFolderURL.appendingPathComponent(intputFileNameWithoutExtension + " \(count)." + fileExtension)
      count += 1
    }
    originalOutputURL = outputFileURL
    if !FileManager.default.fileExists(atPath: outputFolderURL.absoluteString, isDirectory: nil) {
      try? FileManager.default.createDirectory(at: outputFolderURL, withIntermediateDirectories: true)
    }
  }

  var isVideo: Bool {
    switch outputType {
    case .video:
      return true
    default:
      return false
    }
  }

  var isGif: Bool {
    switch outputType {
    case .gif, .gifCompress:
      return true
    default:
      return false
    }
  }

  var isImage: Bool {
    switch outputType {
    case .image:
      return true
    default:
      return false
    }
  }

  var isPdf: Bool {
    switch outputType {
    case .pdfCompress:
      return true
    default:
      return false
    }
  }

  var isMKV: Bool {
    return inputFileURL.pathExtension.lowercased() == "mkv"
  }

  var isFLV: Bool {
    return inputFileURL.pathExtension.lowercased() == "flv"
  }

  var isTS: Bool {
    return inputFileURL.pathExtension.lowercased() == "ts" || inputFileURL.pathExtension.lowercased() == "mts"
  }

  var isAVI: Bool {
    return inputFileURL.pathExtension.lowercased() == "avi"
  }

  var isProgressNotAvailable: Bool {
    return isFLV || isAVI
  }

  var isWebP: Bool {
    return inputFileURL.pathExtension.lowercased() == "webp"
  }

  var isMP4Output: Bool {
    switch outputType {
    case .video(_, _, _, let videoFormat, _, _, _, _, _, _):
      return videoFormat == .mp4
    default:
      return false
    }
  }

  var isSameVideoOutput: Bool {
    switch outputType {
    case .video(_, _, _, let videoFormat, _, _, _, _, _, _):
      return videoFormat == .same
    default:
      return false
    }
  }
}
