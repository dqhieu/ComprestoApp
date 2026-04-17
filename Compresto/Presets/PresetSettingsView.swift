//
//  PresetSettingsView.swift
//  Compresto
//
//  Created by Claude on 18/03/2026.
//

import SwiftUI

struct PresetSettingsView: View {

  @ObservedObject var presetManager = PresetManager.shared
  @State private var editingPreset: CompressionPreset?
  @State private var presetToDelete: CompressionPreset?

  var body: some View {
    Form {
      Section("Built-in Presets") {
        ForEach(CompressionPreset.builtInPresets) { preset in
          presetRow(preset: preset, editable: false)
        }
      }

      Section("My Presets") {
        if presetManager.savedPresets.isEmpty {
          Text("No saved presets yet. Use the Save button next to the Preset picker to save your current settings.")
            .foregroundStyle(.secondary)
            .font(.callout)
        } else {
          ForEach(presetManager.savedPresets) { preset in
            presetRow(preset: preset, editable: true)
          }
        }
      }
    }
    .formStyle(.grouped)
    .sheet(item: $editingPreset) { preset in
      PresetEditorSheet(presetId: preset.id)
    }
    .alert("Delete Preset", isPresented: Binding(
      get: { presetToDelete != nil },
      set: { if !$0 { presetToDelete = nil } }
    )) {
      Button("Delete", role: .destructive) {
        if let preset = presetToDelete {
          presetManager.deletePreset(id: preset.id)
        }
        presetToDelete = nil
      }
      Button("Cancel", role: .cancel) {
        presetToDelete = nil
      }
    } message: {
      if let preset = presetToDelete {
        Text("Are you sure you want to delete \"\(preset.name)\"?")
      }
    }
  }

  @ViewBuilder
  private func presetRow(preset: CompressionPreset, editable: Bool) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(preset.name)
            .fontWeight(preset.isBuiltIn ? .medium : .regular)
          Text(preset.summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        Spacer()
        if editable {
          Button("Edit") {
            editingPreset = preset
          }
          Button {
            presetToDelete = preset
          } label: {
            Image(systemName: "trash")
              .foregroundStyle(.red)
          }
          .buttonStyle(.borderless)
          .help("Delete")
        }
      }
      .padding(.vertical, 2)
    }
  }
}

// MARK: - Preset Editor

struct PresetEditorView: View {

  @Binding var preset: CompressionPreset

  var body: some View {
    Form {
      Section("General") {
        TextField("Name", text: $preset.name)
          .textFieldStyle(.squareBorder)
      }

      Section("Image") {
        Picker("Quality", selection: $preset.imageQuality) {
          ForEach(ImageQuality.allCases, id: \.self) { quality in
            Text(quality.displayText).tag(quality)
          }
        }
        .pickerStyle(.menu)

        Picker("Format", selection: $preset.imageFormat) {
          ForEach(ImageFormat.allCases, id: \.self) { format in
            Text(format.displayText).tag(format)
          }
        }
        .pickerStyle(.menu)

        Picker("Size", selection: $preset.imageSize) {
          ForEach(ImageSize.allCases, id: \.self) { size in
            Text(size.displayText).tag(size)
          }
        }
        .pickerStyle(.menu)

        if preset.imageSize != .same {
          HStack {
            Text("Size value")
            Spacer()
            TextField("Value", value: $preset.imageSizeValue, format: .number)
              .frame(width: 80)
              .textFieldStyle(.squareBorder)
              .multilineTextAlignment(.trailing)
            Text(preset.imageSize == .percentage ? "%" : "px")
              .foregroundStyle(.secondary)
          }
        }
      }

      Section("Video") {
        Picker("Quality", selection: $preset.videoQuality) {
          ForEach([VideoQuality.highest, .high, .good, .medium, .acceptable], id: \.self) { quality in
            Text(quality.displayText).tag(quality)
          }
        }
        .pickerStyle(.menu)

        Picker("Format", selection: $preset.videoFormat) {
          ForEach(VideoFormat.allVideoCases, id: \.self) { format in
            Text(format.displayText).tag(format)
          }
        }
        .pickerStyle(.menu)

        Picker("Resolution", selection: $preset.videoDimension) {
          ForEach(VideoDimension.allCases, id: \.self) { dimension in
            Text(dimension.displayText).tag(dimension)
          }
        }
        .pickerStyle(.menu)

        if preset.videoDimension.needsCustomValue == true {
          HStack {
            Text("Resolution value")
            Spacer()
            TextField("Value", value: $preset.videoDimensionValue, format: .number)
              .frame(width: 80)
              .textFieldStyle(.squareBorder)
              .multilineTextAlignment(.trailing)
            Text("px")
              .foregroundStyle(.secondary)
          }
        }

        Toggle("Remove audio", isOn: $preset.removeAudio)
          .toggleStyle(.switch)
      }

      Section("GIF") {
        Picker("Quality", selection: $preset.gifQuality) {
          ForEach([VideoQuality.highest, .high, .good, .medium, .acceptable], id: \.self) { quality in
            Text(quality.displayText).tag(quality)
          }
        }
        .pickerStyle(.menu)

        Picker("Dimension", selection: $preset.gifDimension) {
          ForEach(GifDimension.allCases, id: \.self) { dimension in
            Text(dimension.displayText).tag(dimension)
          }
        }
        .pickerStyle(.menu)
      }

      Section("PDF") {
        Picker("Quality", selection: $preset.pdfQuality) {
          ForEach(PDFQuality.allCases, id: \.self) { quality in
            Text(quality.displayText).tag(quality)
          }
        }
        .pickerStyle(.menu)
      }
    }
    .formStyle(.grouped)
  }
}

// MARK: - Preset Editor Sheet

struct PresetEditorSheet: View {

  let presetId: String
  @ObservedObject var presetManager = PresetManager.shared
  @Environment(\.dismiss) private var dismiss
  @State private var draft: CompressionPreset?

  var body: some View {
    Group {
      if draft != nil {
        PresetEditorView(preset: Binding(
          get: { draft! },
          set: { draft = $0 }
        ))
      }
    }
    .navigationTitle(draft?.name ?? "Edit Preset")
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Done") {
          save()
          dismiss()
        }
      }
    }
    .frame(minWidth: 400, idealWidth: 450, minHeight: 500, idealHeight: 600)
    .onAppear {
      draft = presetManager.savedPresets.first(where: { $0.id == presetId })
    }
  }

  private func save() {
    guard let draft else { return }
    presetManager.updatePreset(draft)
  }
}
