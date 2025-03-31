//
//  VideoOptionsView.swift
//  CompressX
//
//  Created by Dinh Quang Hieu on 1/3/25.
//

import SwiftUI

struct VideoOptionsView: View {

  @AppStorage("outputFormat") var outputFormat: VideoFormat = .same
  @AppStorage("videoQuality") var videoQuality: VideoQuality = .high
  @AppStorage("videoDimension") var videoDimension: VideoDimension = .same
  @AppStorage("videoGifQuality") var videoGifQuality: VideoQuality = .high
  @AppStorage("videoGifDimension") var videoGifDimension: GifDimension = .same
  @AppStorage("removeAudio") var removeAudio = false

  @ObservedObject var jobManager = JobManager.shared

  @Binding var showPreserveTransparency: Bool
  @Binding var shouldPreserveTransparency: Bool
  @Binding var isInputWebM: Bool
  @Binding var fpsValue: Double
  @Binding var hasAudio: Bool
  @Binding var targetFileSize: Double

  var videoQualities: [VideoQuality] {
    if showPreserveTransparency && shouldPreserveTransparency && outputFormat != .webm {
      return [.highest, .ultraHD, .fullHD]
    }
    return [.highest, .high, .good, .medium, .acceptable, .fileSize]
  }

  var gifQualities: [VideoQuality] = [.highest, .high, .good, .medium, .acceptable]

  var body: some View {
    Section {
      if outputFormat != .gif {
        VStack(alignment: .leading) {
          Picker(selection: $videoQuality) {
            ForEach(videoQualities, id: \.self) { quality in
              Text(quality.displayText).tag(quality.rawValue)
            }
          } label: {
            Text("Video quality")
          }
          .pickerStyle(.menu)
          if videoQuality == .fileSize {
            HStack {
              Text("Target")
                .font(.caption)
                .padding(.trailing, 4)
//              Slider(value: $targetFileSize, in: fileSizeRange, step: fileSizeRange.upperBound / 20)
//                .labelsHidden()
              Slider(
                value: Binding(
                  get: { targetFileSize },
                  set: { newValue in
                    let base: Int = Int(newValue.rounded())
                    let modulo: Int = base % 10
                    targetFileSize = Double(base - modulo)
                  }
                ),
                in: fileSizeRange
              )
              .labelsHidden()
              Text("\(fileSizeString(from: Int64(targetFileSize)))")
                .frame(width: 60, alignment: .trailing)
            }
          }
        }
        Picker(selection: $videoDimension) {
          ForEach(VideoDimension.allCases, id: \.self) { dimension in
            Text(dimension.displayText).tag(dimension.rawValue)
          }
        } label: {
          Text("Video resolution")
        }
        .pickerStyle(.menu)
      }
      Picker(selection: $outputFormat) {
        ForEach(VideoFormat.allCases, id: \.self) { format in
          Text(format.displayText).tag(format.rawValue)
        }
      } label: {
        Text("Video format")
      }
      .pickerStyle(.menu)
      .disabled(isInputWebM)
      .onChange(of: outputFormat, perform: { newValue in
        if newValue == .webm {
          shouldPreserveTransparency = true
        }
      })
      if outputFormat == .gif {
        VStack(alignment: .leading) {
          HStack {
            Text("FPS")
            Text("\(Int(fpsValue))")
            Spacer()
          }
          Slider(value: $fpsValue, in: 10...50, step: 1)
            .labelsHidden()
        }
        Picker(selection: $videoGifQuality) {
          ForEach(gifQualities, id: \.self) { quality in
            Text(quality.displayText).tag(quality.rawValue)
          }
        } label: {
          Text("Gif quality")
        }
        .pickerStyle(.menu)
        Picker(selection: $videoGifDimension) {
          ForEach(GifDimension.allCases, id: \.self) { dimension in
            Text(dimension.displayText).tag(dimension.rawValue)
          }
        } label: {
          Text("Gif dimension")
        }
        .pickerStyle(.menu)
      }
      if showPreserveTransparency {
        Toggle("Preserve transparency", isOn: $shouldPreserveTransparency)
          .toggleStyle(.switch)
          .onChange(of: shouldPreserveTransparency, perform: { newValue in
            if newValue == true {
              resetOptionForTransparencyIfNeeded()
            }
          })
          .disabled(outputFormat == .webm)
      }
      if hasAudio && outputFormat != .gif {
        Toggle("Remove audio", isOn: $removeAudio)
          .toggleStyle(.switch)
          .disabled(shouldPreserveTransparency)
      }
    }
    .disabled(jobManager.isRunning)
    .task {
      targetFileSize = fileSizeRange.upperBound
    }
    .onChange(of: jobManager.inputFileURLs, perform: { newValue in
      targetFileSize = fileSizeRange.upperBound
    })
  }

  private var fileSizeRange: ClosedRange<Double> {
    let allFileSizesInByte = jobManager.inputFileURLs.map { $0.fileSize }.compactMap { $0 }
    let maxSize = Double(allFileSizesInByte.max() ?? 0)
    if maxSize > 1024 {
      return 1024...maxSize
    }
    return 0...1
  }

  private func resetOptionForTransparencyIfNeeded() {
    if !videoQualities.contains(videoQuality) {
      videoQuality = .highest
    }
    removeAudio = false
  }
}
