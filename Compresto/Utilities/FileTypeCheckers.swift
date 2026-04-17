//
//  FileTypeCheckers.swift
//  Compresto
//

import Foundation
import UniformTypeIdentifiers

let videoSupportedTypes = [UTType.mpeg4Movie, .movie, .quickTimeMovie, .avi, .mpeg, .mpeg2Video, .video, UTType("org.matroska.mkv"), UTType.mpeg2TransportStream].compactMap { $0 }
let imageSupportedTypes = [UTType.image, .bmp, .jpeg]
let pdfSupportedTypes = [UTType.pdf, .epub]
let extraVideoSupportedTypes = ["mkv", "ts", "mts"]
let notSupportedTypes: [String] = []

func checkFileType(url: URL) -> FileType {
  if isPDFFile(url: url) {
    return .pdf
  }
  if isGifFile(url: url) {
    return .gif
  }
  if isImageFile(url: url) {
    if isPNGFile(url: url) {
      return .image(.png)
    }
    return .image(.jpg)
  }
  for type in notSupportedTypes {
    if type.lowercased() == url.pathExtension.lowercased() {
      return .notSupported
    }
  }
  for type in videoSupportedTypes {
    if url.contains(type) {
      return .video
    }
  }
  for type in extraVideoSupportedTypes {
    if url.pathExtension.lowercased() == type {
      return .video
    }
  }
  return .notSupported
}

func isImageFile(url: URL) -> Bool {
  for imageSupportedType in imageSupportedTypes {
    if url.contains(imageSupportedType) {
      return true
    }
  }
  return false
}

func isPDFFile(url: URL) -> Bool {
  return url.pathExtension.lowercased() == "pdf" || url.pathExtension.lowercased() == "epub"
}

func isGifFile(url: URL) -> Bool {
  return url.pathExtension.lowercased() == "gif"
}

func isPNGFile(url: URL) -> Bool {
  return url.pathExtension.lowercased() == "png"
}

func isPdfFile(url: URL) -> Bool {
  return url.pathExtension.lowercased() == "pdf"
}

func isRawImage(url: URL) -> Bool {
  return url.pathExtension.lowercased() == "dng" || url.pathExtension.lowercased() == "heic"
}

func isSVGFile(url: URL) -> Bool {
  return url.pathExtension.lowercased() == "svg"
}

func isTiffFile(url: URL) -> Bool {
  return url.pathExtension.lowercased() == "tif"
}

func preProcessRawImage(inputFileURL: URL) -> URL? {
  // Generate a random UUID string
  let uuid = UUID().uuidString

  // Get the file name and extension
  let fileName = inputFileURL.deletingPathExtension().lastPathComponent
  let fileExtension = inputFileURL.pathExtension

  // Create new filename with UUID
  let newFileName = "\(fileName)_\(uuid).\(fileExtension)"

  let outputFile = FileManager.default.temporaryDirectory.appending(path: newFileName)
  if convertDNGToJPEG(inputURL: inputFileURL, outputURL: outputFile) {
    return outputFile
  }
  return nil
}

func isFileSupported(url: URL) -> Bool {
  let filetype = checkFileType(url: url)
  return filetype != .notSupported
}

func isValidFFmpegPath(_ path: String) -> Bool {
  return path.lowercased().hasSuffix("ffmpeg")
}

func isValidPngquantPath(_ path: String) -> Bool {
  return path.lowercased().hasSuffix("pngquant")
}

func isValidGifskiPath(_ path: String) -> Bool {
  return path.lowercased().hasSuffix("gifski")
}
