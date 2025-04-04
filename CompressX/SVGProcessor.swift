//
//  SVGProcessor.swift
//  CompressX
//
//  Created by Dinh Quang Hieu on 6/7/24.
//

import Foundation
import AppKit
import SwiftDraw

class SVGProcessor {
  static func convert(job: Job, imageQuality: ImageQuality, imageFormat: ImageFormat, imageSize: ImageSize, imageSizeValue: Int) -> String? {
    guard let svg = SVG(fileURL: job.inputFileURL) else {
      return "Failed to initialize SVG"
    }
    let newSize: CGSize = {
      if let imageRep = NSImageRep(contentsOf: job.inputFileURL), imageRep.pixelsWide > 0, imageRep.pixelsHigh > 0 {
        return getSize(
          inputWidth: CGFloat(imageRep.pixelsWide),
          inputHeight: CGFloat(imageRep.pixelsHigh),
          imageSize: imageSize,
          imageSizeValue: imageSizeValue
        )
      }
      return getSize(
        inputWidth: CGFloat(svg.size.width),
        inputHeight: CGFloat(svg.size.height),
        imageSize: imageSize,
        imageSizeValue: imageSizeValue
      )
    }()
    switch imageFormat {
    case .same:
      do {
        try FileManager.default.copyItem(at: job.inputFileURL, to: job.outputFileURL)
        return nil
      } catch {
        return String(describing: error)
      }
    case .jpg:
      do {
        let jpgImageData = try svg.jpegData(size: newSize, scale: 1, compressionQuality: imageQuality.svgImageQualityLevel, insets: .zero)
        try jpgImageData.write(to: job.outputFileURL)
      } catch {
        return String(describing: error)
      }
    case .png:
      do {
        let pngImageData = try svg.pngData(size: newSize, scale: 1, insets: .zero)
        if let data = NSBitmapImageRep(data: pngImageData)?.representation(using: .png, properties: [NSBitmapImageRep.PropertyKey.compressionFactor : imageQuality.svgImageQualityLevel]) {
          try data.write(to: job.outputFileURL)
        } else {
          return "Failed to initialize PNG"
        }
      } catch {
        return String(describing: error)
      }
    case .webp:
      return nil
    }
    return nil
  }
}
