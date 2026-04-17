//
//  SingleFilePreviewView.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 2/17/25.
//

import SwiftUI
import AVKit
import Combine

struct SingleFilePreviewView: View {

  var file: InputFile
  @Binding var startTimes: [URL: CMTime]
  @Binding var endTimes: [URL: CMTime]

  var body: some View {
    switch file.fileType {
    case .image:
      SingleImagePreviewView(file: file)
    case .gif:
      SingleGifPreviewView(file: file)
    case .video:
      SingleVideoPlayerView(file: file, startTimes: $startTimes, endTimes: $endTimes)
    case .pdf:
      SinglePDFPreviewView(file: file)
    case .notSupported:
      EmptyView()
    }
  }
}
