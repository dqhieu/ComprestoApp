//
//  VideoOptionsView.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 1/3/25.
//

import SwiftUI

enum FileSizeUnit: String, CaseIterable {
  case kb = "KB"
  case mb = "MB"
  case gb = "GB"
  
  var bytesMultiplier: Double {
    switch self {
    case .kb: return 1024
    case .mb: return 1024 * 1024
    case .gb: return 1024 * 1024 * 1024
    }
  }
}

struct VideoOptionsView: View {

  @AppStorage("outputFormat") var outputFormat: VideoFormat = .same
  @AppStorage("videoQuality") var videoQuality: VideoQuality = .high
  @AppStorage("videoDimension") var videoDimension: VideoDimension = .same
  @AppStorage("videoDimensionValue") var videoDimensionValue: Int = 1920
  @AppStorage("videoDimensionValueText") var videoDimensionValueText: String = "1920"
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
  @Binding var checkingAudioTrack: Bool

  @State private var targetFileSizeText: String = ""
  @AppStorage("selectedUnit") private var selectedUnit: FileSizeUnit = .mb

  var videoQualities: [VideoQuality] {
    if showPreserveTransparency && shouldPreserveTransparency && outputFormat != .webm {
      return [.highest, .ultraHD, .fullHD]
    }
    return [.highest, .high, .good, .medium, .acceptable, .fileSize]
  }

  var gifQualities: [VideoQuality] = [.highest, .high, .good, .medium, .acceptable]

  var body: some View {
    Section {
      // Hide video quality/dimension when extracting audio
      Picker(selection: $outputFormat) {
        ForEach(VideoFormat.allCases, id: \.self) { format in
          // Hide MP3 if video has no audio or still checking
          if format == .mp3 && (!hasAudio || checkingAudioTrack) {
            EmptyView()
          } else {
            Text(format.displayText).tag(format.rawValue)
          }
        }
      } label: {
        Text("Output format")
      }
      .pickerStyle(.menu)
      .onChange(of: outputFormat, perform: { newValue in
        if newValue == .webm || newValue == .same && isInputWebM {
          shouldPreserveTransparency = true
        } else {
          shouldPreserveTransparency = false
        }
      })
      if outputFormat != .gif && outputFormat != .mp3 {
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
            VStack(alignment: .leading, spacing: 8) {
              HStack(spacing: 8) {
                Text("Target file size")
                  .font(.caption)
                Spacer()
                TextField("Size", text: $targetFileSizeText)
                  .textFieldStyle(.roundedBorder)
                  .labelsHidden()
                  .onChange(of: targetFileSizeText) { newValue in
                    updateTargetFileSize()
                  }

                Picker("Unit", selection: $selectedUnit) {
                  ForEach(FileSizeUnit.allCases, id: \.self) { unit in
                    Text(unit.rawValue).tag(unit)
                  }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .onChange(of: selectedUnit) { _ in
                  updateTargetFileSize()
                }
              }
            }
          }
        }
        VStack {
          Picker(selection: $videoDimension) {
            ForEach(VideoDimension.allCases, id: \.self) { dimension in
              Text(dimension.displayText).tag(dimension.rawValue)
            }
          } label: {
            Text("Video resolution")
          }
          .pickerStyle(.menu)
          if videoDimension.needsCustomValue {
            HStack {
              TextField("Value", text: $videoDimensionValueText, onEditingChanged: { (editingChanged) in
                if !editingChanged {
                  onDimensionValueSubmit()
                }
              })
              .frame(width: 100)
              .textFieldStyle(.squareBorder)
              .labelsHidden()
              .multilineTextAlignment(.trailing)
              .onSubmit(onDimensionValueSubmit)
              .task {
                videoDimensionValueText = String(videoDimensionValue)
              }
              Text("px")
                .foregroundStyle(.secondary)
              Spacer()
              Button {
                onDimensionValueSubmit()
              } label: {
                Text("Update")
              }
              .disabled(videoDimensionValue == Int(videoDimensionValueText))
            }
          }
        }
      }
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
      // Hide transparency option when output is audio-only
      if showPreserveTransparency && outputFormat != .mp3 {
        Toggle("Preserve transparency", isOn: $shouldPreserveTransparency)
          .toggleStyle(.switch)
          .onChange(of: shouldPreserveTransparency, perform: { newValue in
            if newValue == true {
              resetOptionForTransparencyIfNeeded()
            }
          })
          .disabled(outputFormat == .webm)
      }
      if checkingAudioTrack {
        HStack {
          Text("Checking audio track...")
          ProgressView()
            .controlSize(.small)
          Spacer()
        }
      } else if hasAudio && outputFormat != .gif && outputFormat != .mp3 {
        // Hide "Remove audio" toggle when output IS audio
        Toggle("Remove audio", isOn: $removeAudio)
          .toggleStyle(.switch)
          .disabled(shouldPreserveTransparency)
      }
    }
    .disabled(jobManager.isRunning)
    .task {
      updateTargetFileSize()
      updateTextFromTargetFileSize()
    }
    .onChange(of: jobManager.inputFileURLs, perform: { newValue in
      updateTargetFileSize()
      updateTextFromTargetFileSize()
    })
  }

  private func resetOptionForTransparencyIfNeeded() {
    if !videoQualities.contains(videoQuality) {
      videoQuality = .highest
    }
    removeAudio = false
  }
  
  private func updateTargetFileSize() {
    guard let value = Double(targetFileSizeText), value > 0 else {
      return
    }
    targetFileSize = value * selectedUnit.bytesMultiplier
  }
  
  private func onDimensionValueSubmit() {
    if let value = Int(videoDimensionValueText), value > 0 && value <= 65535 {
      videoDimensionValue = value
    } else {
      let alert = NSAlert()
      alert.messageText = "Invalid value"
      if (Int(videoDimensionValueText) ?? 0) <= 0 {
        alert.informativeText = "Value must be a positive integer"
      } else if (Int(videoDimensionValueText) ?? 0) > 65535 {
        alert.informativeText = "Value is too large"
      }
      alert.addButton(withTitle: "OK")
      let _ = alert.runModal()
    }
  }

  private func updateTextFromTargetFileSize() {
    // Convert bytes to the most appropriate unit
    if targetFileSize >= FileSizeUnit.gb.bytesMultiplier {
      selectedUnit = .gb
      targetFileSizeText = String(format: "%.0f", targetFileSize / FileSizeUnit.gb.bytesMultiplier)
    } else if targetFileSize >= FileSizeUnit.mb.bytesMultiplier {
      selectedUnit = .mb
      targetFileSizeText = String(format: "%.0f", targetFileSize / FileSizeUnit.mb.bytesMultiplier)
    } else {
      selectedUnit = .kb
      targetFileSizeText = String(format: "%.0f", targetFileSize / FileSizeUnit.kb.bytesMultiplier)
    }
  }
}
