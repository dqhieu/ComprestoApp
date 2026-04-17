//
//  Extensions.swift
//  Compresto
//

import Foundation
import AVFoundation
import AppKit
import UniformTypeIdentifiers

func fileSizeString(from bytes: Int64?) -> String {
  guard let bytes = bytes else { return "" }
  return fileByteCountFormatter.string(fromByteCount: bytes)
}

func getFileCreationDate(from url: URL) throws -> Date? {
  let attributes = try FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))
  return attributes[.creationDate] as? Date
}

func changeAppIcon(image: NSImage) {
  NSApp.applicationIconImage = image
  NSWorkspace.shared.setIcon(image, forFile: Bundle.main.bundlePath)
  let task = Process()
  task.launchPath = "/usr/bin/env"
  task.arguments = ["touch", Bundle.main.bundlePath]
  try? task.run()
}

let fileByteCountFormatter: ByteCountFormatter = {
  let bcf = ByteCountFormatter()
  bcf.allowedUnits = [.useAll]
  bcf.countStyle = .file
  return bcf
}()

var brewPath: String? {
  if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") {
    return "/opt/homebrew/bin/brew"
  }
  if FileManager.default.fileExists(atPath: "/usr/local/bin/brew") {
    return "/usr/local/bin/brew"
  }
  return nil
}

extension String {
  func toTimeInterval() -> TimeInterval? {
    let components = self.components(separatedBy: "=")
    guard components.count == 2, components[0] == "time", let timeString = components.last else {
      return nil
    }

    let timeComponents = timeString.components(separatedBy: ":")
    guard timeComponents.count == 3,
            let hours = Double(timeComponents[0]),
            let minutes = Double(timeComponents[1]),
            let seconds = Double(timeComponents[2]) else {
      return nil
    }

    return hours * 3600 + minutes * 60 + seconds
  }

  var nonEmptyString: String? {
    return self.isEmpty == true ? nil : self
  }
}

func convertISO8601ToReadableDate(isoDate: String) -> String {
  let isoFormatter = ISO8601DateFormatter()
  isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds] // Include fractional seconds
  guard let date = isoFormatter.date(from: isoDate) else {
    return isoDate
  }

  let readableFormatter = DateFormatter()
  readableFormatter.dateStyle = .long
  readableFormatter.timeStyle = .none

  return readableFormatter.string(from: date)
}

/* Example usage
let doubleValue = 3661.0 // For 1 hour, 1 minute, and 1 second
let formattedString = formatTimeInterval(doubleValue)
print(formattedString) // Outputs: "01:01:01"
 */
func formatTimeInterval(_ interval: Double) -> String {
  let formatter = DateComponentsFormatter()
  formatter.allowedUnits = [.hour, .minute, .second]
  formatter.unitsStyle = .positional
  formatter.zeroFormattingBehavior = .pad

  return formatter.string(from: TimeInterval(interval)) ?? ""
}

extension CGSize {

  var is8K: Bool {
    return width > 3840 && height > 2160
  }

  var is4K: Bool {
    return width > 1920 && height > 1080
  }

  var isFullHD: Bool {
    return width <= 1920 && height <= 1080
  }

  var isHD: Bool {
    return width <= 1280 && height <= 720
  }
}

extension URL {
  var fileSize: Int64? {
    if let values = try? resourceValues(forKeys: [URLResourceKey.fileSizeKey]), let fileBytes = values.fileSize {
      return Int64(fileBytes)
    }
    return nil
  }

  var mimeType: String {
    return UTType(filenameExtension: self.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
  }

  func contains(_ uttype: UTType) -> Bool {
    return UTType(mimeType: self.mimeType)?.conforms(to: uttype) ?? false
  }

  var checkVideoTransparency: Bool {
    get async throws {
      let asset = AVAsset(url: self)
      let videoTracks = try await asset.loadTracks(withMediaType: .video)

      guard let track = videoTracks.first else { return false }

      let formatDescriptions = try await track.load(.formatDescriptions)
      for formatDescription in formatDescriptions {
        if let containsAlphaChannel = formatDescription.extensions[CMFormatDescription.Extensions.Key.containsAlphaChannel],
           containsAlphaChannel.propertyListRepresentation as? Bool == true {
          return true
        }
        if formatDescription.extensions[CMFormatDescription.Extensions.Key.alphaChannelMode] != nil {
          return true
        }
      }
      return false
    }
  }
}

var hasNotch: Bool {
  return notchSize != nil
}

var notchSize: NSSize? {
  if let screen = getScreenWithMouse(),
     screen.safeAreaInsets.top != 0,
     let auxiliaryTopLeftArea = screen.auxiliaryTopLeftArea,
     let auxiliaryTopRightArea = screen.auxiliaryTopLeftArea {
    return NSSize(
      width: screen.visibleFrame.width - auxiliaryTopLeftArea.width - auxiliaryTopRightArea.width,
      height: screen.frame.height - screen.visibleFrame.height - screen.visibleFrame.origin.y
    )
  }
  return nil
}

func getScreenWithMouse() -> NSScreen? {
  let mouseLocation = NSEvent.mouseLocation
  let screens = NSScreen.screens
  let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) })

  return screenWithMouse
}

var appVersion: String {
  var result = ""
  if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
    result = appVersion
  }
  if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
    result += " (\(buildNumber))"
  }

  return result
}

var appVersionOnly: String {
  return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
}

func getSubfolders(in folderURL: URL) -> [URL] {
  let fileManager = FileManager.default

  let allItems = try? fileManager.contentsOfDirectory(
    at: folderURL,
    includingPropertiesForKeys: nil,
    options: [.skipsHiddenFiles]
  )

  let subfolders = allItems?.filter { $0.hasDirectoryPath }

  return subfolders ?? []
}

func getFiles(in folderURL: URL) -> [URL] {
  let fileManager = FileManager.default

  let allItems = try? fileManager.contentsOfDirectory(
    at: folderURL,
    includingPropertiesForKeys: nil,
    options: [.skipsHiddenFiles]
  )

  let files = allItems?.filter { !$0.hasDirectoryPath }

  return files ?? []
}

func flatten(urls: [URL], maxDepth: Int) -> [URL] {
  guard !urls.isEmpty, maxDepth > 0 else { return [] }
  let files = urls.filter { !$0.hasDirectoryPath }
  let folders = urls.filter { $0.hasDirectoryPath }
  let flattenFiles = folders.flatMap { getFiles(in: $0) }
  let subfolders = folders.flatMap { getSubfolders(in: $0) }
  return files + flattenFiles + flatten(urls: subfolders, maxDepth: maxDepth - 1)
}

func getFoldersRecursively(url: URL, maxDepth: Int) -> [URL] {
  guard maxDepth > 0 else { return [] }
  let subfolders = getSubfolders(in: url)
  if maxDepth == 1 {
    return [url]
  }
  let deeperFolders = subfolders.flatMap { getFoldersRecursively(url: $0, maxDepth: maxDepth - 1) }
  return [url] + deeperFolders
}

func hasSubfolders(urls: [URL]) -> Bool {
  let folders = urls.filter { $0.hasDirectoryPath }
  for folder in folders {
    let subfolders = getSubfolders(in: folder)
    if !subfolders.isEmpty {
      return true
    }
  }
  return false
}

extension Date {
  var toISO8601DateTime: String {
    let formatter = DateFormatter()
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd'T'HHmmss"
    let result = formatter.string(from: self)
    return result.replacingOccurrences(of: ":", with: ".")
  }

  var toISO8601Date: String {
    let formatter = DateFormatter()
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: self)
  }

  var toISO8601Time: String {
    let formatter = DateFormatter()
    formatter.timeZone = .current
    formatter.dateFormat = "HHmmss"
    let result = formatter.string(from: self)
    return result
  }
}

func normalizeVersion(_ version: String) -> String {
  // Split the version string by "."
  var parts = version.split(separator: ".").map(String.init)

  // Ensure that we always have at least 3 parts
  while parts.count < 3 {
    parts.append("0")
  }

  // Join them back into a normalized version string
  return parts.joined(separator: ".")
}

func compareVersions(_ version1: String, _ version2: String) -> Int {
  // Normalize and split both versions, converting each part to Int
  let v1Parts = normalizeVersion(version1).split(separator: ".").compactMap { Int($0) }
  let v2Parts = normalizeVersion(version2).split(separator: ".").compactMap { Int($0) }

  // Compare each segment
  for i in 0..<3 {
    if v1Parts[i] > v2Parts[i] {
      return 1
    } else if v1Parts[i] < v2Parts[i] {
      return -1
    }
  }

  // If all segments are equal, return 0
  return 0
}

extension Array: @retroactive RawRepresentable where Element: Codable {
  public init?(rawValue: String) {
    guard let data = rawValue.data(using: .utf8),
          let result = try? JSONDecoder().decode([Element].self, from: data)
    else {
      return nil
    }
    self = result
  }

  public var rawValue: String {
    guard let data = try? JSONEncoder().encode(self),
          let result = String(data: data, encoding: .utf8)
    else {
      return "[]"
    }
    return result
  }
}

extension Dictionary: RawRepresentable where Key == String, Value == Int {
  public init?(rawValue: String) {
    guard let data = rawValue.data(using: .utf8),  // convert from String to Data
          let result = try? JSONDecoder().decode([String: Int].self, from: data)
    else {
      return nil
    }
    self = result
  }

  public var rawValue: String {
    guard let data = try? JSONEncoder().encode(self),   // data is  Data type
          let result = String(data: data, encoding: .utf8) // coerce NSData to String
    else {
      return "{}"  // empty Dictionary resprenseted as String
    }
    return result
  }
}

extension Optional where Wrapped == String {
  var isNilOrEmpty: Bool {
    return self?.isEmpty ?? true
  }
}
