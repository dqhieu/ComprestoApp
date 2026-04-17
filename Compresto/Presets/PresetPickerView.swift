//
//  PresetPickerView.swift
//  Compresto
//
//  Created by Claude on 18/03/2026.
//

import SwiftUI

struct PresetPickerView: View {

  @ObservedObject var presetManager = PresetManager.shared
  @State private var showSaveAlert = false
  @State private var newPresetName = ""

  var body: some View {
    Section {
      HStack {
        Text("Preset")
        Button {
          newPresetName = ""
          showSaveAlert = true
        } label: {
          Text("Save")
            .foregroundStyle(.secondary)
        }
        .help("Save current settings as preset")
        Spacer(minLength: 0)
        Picker("", selection: $presetManager.selectedPresetId) {
          Text("Custom").tag("")
          Section("Built-in") {
            ForEach(CompressionPreset.builtInPresets) { preset in
              Text(preset.name).tag(preset.id)
            }
          }
          if !presetManager.savedPresets.isEmpty {
            Section("My Presets") {
              ForEach(presetManager.savedPresets) { preset in
                Text(preset.name).tag(preset.id)
              }
            }
          }
        }
        .pickerStyle(.menu)
        .onChange(of: presetManager.selectedPresetId, perform: { newValue in
          if let preset = presetManager.preset(for: newValue) {
            presetManager.applyPreset(preset)
          }
        })
      }
    }
    .alert("Save Preset", isPresented: $showSaveAlert) {
      TextField("Preset name", text: $newPresetName)
      Button("Save") {
        let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
          presetManager.savePreset(name: name)
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Enter a name for this preset.")
    }
  }
}
