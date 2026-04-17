//
//  ImageHelpers.swift
//  Compresto
//

import Foundation
import AppKit
import CoreImage

func getSize(inputWidth: CGFloat, inputHeight: CGFloat, imageSize: ImageSize, imageSizeValue: Int) -> CGSize {
  switch imageSize {
  case .same:
    return CGSize(width: inputWidth, height: inputHeight)
  case .percentage:
    return CGSize(
      width: inputWidth * CGFloat(imageSizeValue) / 100,
      height: inputHeight * CGFloat(imageSizeValue) / 100
    )
  case .maxHeight:
    if inputHeight <= CGFloat(imageSizeValue) {
      return CGSize(width: inputWidth, height: inputHeight)
    } else {
      return CGSize(
        width: inputWidth * CGFloat(imageSizeValue) / inputHeight,
        height: CGFloat(imageSizeValue)
      )
    }
  case .maxWidth:
    if inputWidth <= CGFloat(imageSizeValue) {
      return CGSize(width: inputWidth, height: inputHeight)
    } else {
      return CGSize(
        width: CGFloat(imageSizeValue),
        height: inputHeight * CGFloat(imageSizeValue) / inputWidth
      )
    }
  case .maxLongEdge:
    if inputWidth < inputHeight {
      return getSize(
        inputWidth: inputWidth,
        inputHeight: inputHeight,
        imageSize: .maxHeight,
        imageSizeValue: imageSizeValue
      )
    } else {
      return getSize(
        inputWidth: inputWidth,
        inputHeight: inputHeight,
        imageSize: .maxWidth,
        imageSizeValue: imageSizeValue
      )
    }
  case .maxShortEdge:
    if inputWidth < inputHeight {
      return getSize(
        inputWidth: inputWidth,
        inputHeight: inputHeight,
        imageSize: .maxWidth,
        imageSizeValue: imageSizeValue
      )
    } else {
      return getSize(
        inputWidth: inputWidth,
        inputHeight: inputHeight,
        imageSize: .maxHeight,
        imageSizeValue: imageSizeValue
      )
    }
  }
}

func saveImageAsPNG(image: NSImage, toPath path: String) -> Bool {
  guard let tiffData = image.tiffRepresentation,
        let bitmapImageRep = NSBitmapImageRep(data: tiffData) else {
    return false
  }

  guard let pngData = bitmapImageRep.representation(using: .png, properties: [:]) else {
    return false
  }

  do {
    try pngData.write(to: URL(fileURLWithPath: path))
    return true
  } catch {
    print("Failed to save image: \(error)")
    return false
  }
}

func saveImageAsJPEG(image: NSImage, toPath path: String, compressionFactor: Float = 0.9) -> Bool {
  guard let tiffData = image.tiffRepresentation,
        let bitmapImageRep = NSBitmapImageRep(data: tiffData) else {
    return false
  }

  let properties: [NSBitmapImageRep.PropertyKey: Any] = [.compressionFactor: compressionFactor]

  guard let jpegData = bitmapImageRep.representation(using: .jpeg, properties: properties) else {
    return false
  }

  do {
    try jpegData.write(to: URL(fileURLWithPath: path))
    return true
  } catch {
    print("Failed to save image: \(error)")
    return false
  }
}

func convertDNGToJPEG(inputURL: URL, outputURL: URL) -> Bool {
  let context = CIContext()
  guard let rawImage = CIImage(contentsOf: inputURL) else {
    return false
  }

  guard let jpegData = context.jpegRepresentation(of: rawImage, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, options: [:]) else {
    return false
  }

  do {
    try jpegData.write(to: outputURL)
  } catch {
    return false
  }

  return true
}

extension NSImage {
  func resized(to newSize: NSSize?) -> NSImage {
    guard let newSize = newSize else { return self }
    if let bitmapRep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: Int(newSize.width), pixelsHigh: Int(newSize.height),
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) {
      bitmapRep.size = newSize
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
      draw(in: NSRect(x: 0, y: 0, width: newSize.width, height: newSize.height), from: .zero, operation: .copy, fraction: 1.0)
      NSGraphicsContext.restoreGraphicsState()

      let resizedImage = NSImage(size: newSize)
      resizedImage.addRepresentation(bitmapRep)
      return resizedImage
    }

    return self
  }

  func squareCrop() -> NSImage {
    let imageSize = self.size
    var rect: CGRect = .zero
    if imageSize.width < imageSize.height {
      rect = CGRect(
        x: 0,
        y: (imageSize.height - imageSize.width) / 2,
        width: imageSize.width,
        height: imageSize.width
      )
    } else if imageSize.width > imageSize.height {
      rect = CGRect(
        x: (imageSize.width - imageSize.height) / 2,
        y: 0,
        width: imageSize.height,
        height: imageSize.height
      )
    } else {
      return self
    }
    let result = NSImage(size: rect.size)
    result.lockFocus()

    self.draw(in: NSRect(origin: .zero, size: result.size),
              from: rect,
              operation: .copy,
              fraction: 1.0)

    result.unlockFocus()

    return result
  }
}

func imageHasAlphaChannel(_ image: NSImage) -> Bool {
  guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return false }
  let alphaInfo = cgImage.alphaInfo
  switch alphaInfo {
  case .first, .last, .premultipliedFirst, .premultipliedLast:
    return true
  default:
    return false
  }
}
