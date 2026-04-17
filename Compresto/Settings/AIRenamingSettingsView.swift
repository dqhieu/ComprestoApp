//
//  AIRenamingSettingsView.swift
//  Compresto
//

import SwiftUI

struct AIRenamingSettingsView: View {

  @ObservedObject private var manager = AIRenamingManager.shared

  @State private var apiKeyInput: String = ""
  @State private var selectedProvider: AIRenamingProviderType = .openai
  @State private var selectedPreset: AIRenamingPreset = .descriptive
  @State private var selectedModel: OpenAIModel = .gpt5Nano

  var body: some View {
    Form {
      Section {
        Toggle("Enable AI Renaming", isOn: $manager.aiRenamingEnabled)
          .toggleStyle(.switch)
      }

      Section("Provider") {
        Picker("Provider", selection: $selectedProvider) {
          ForEach(AIRenamingProviderType.allCases.filter(\.isImplemented)) { provider in
            Text(provider.displayName)
              .tag(provider)
          }
        }
        .disabled(!manager.aiRenamingEnabled)
        .onChange(of: selectedProvider) { newValue in
          manager.providerTypeRaw = newValue.rawValue
          apiKeyInput = manager.apiKey(for: newValue)
          manager.keyVerificationResult = nil
        }

        if selectedProvider.isImplemented {
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              SecureField("API Key", text: $apiKeyInput)
                .textFieldStyle(.roundedBorder)
              .onChange(of: apiKeyInput) { newValue in
                manager.saveAPIKey(newValue, for: selectedProvider)
                manager.keyVerificationResult = nil
              }

            Button {
              Task { await manager.verifyAPIKey(for: selectedProvider) }
            } label: {
              if manager.isVerifyingKey {
                ProgressView()
                  .controlSize(.small)
              } else if let result = manager.keyVerificationResult {
                Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                  .foregroundColor(result ? .green : .red)
              } else {
                Text("Verify")
              }
            }
            .disabled(apiKeyInput.isEmpty || manager.isVerifyingKey || !manager.aiRenamingEnabled)
            }
            Text("Stored securely in Keychain")
              .foregroundColor(.secondary)
              .font(.caption)
          }

          VStack(alignment: .leading, spacing: 4) {
            Picker("Model", selection: $selectedModel) {
              ForEach(OpenAIModel.allCases) { model in
                VStack(alignment: .leading) {
                  Text(model.displayName)
                }
                .tag(model)
              }
            }
            .onChange(of: selectedModel) { newValue in
              manager.openaiModelRaw = newValue.rawValue
            }

            Text(selectedModel.costDescription)
              .foregroundColor(.secondary)
              .font(.caption)
          }
        }
      }
      .disabled(!manager.aiRenamingEnabled)

      Section("Naming Style") {
        Picker("Preset", selection: $selectedPreset) {
          ForEach(AIRenamingPreset.allCases) { preset in
            Text(preset.displayName)
              .tag(preset)
          }
        }
        .onChange(of: selectedPreset) { newValue in
          manager.presetRaw = newValue.rawValue
        }

        if selectedPreset == .custom {
          TextField("Custom prompt", text: $manager.customPrompt, axis: .vertical)
            .lineLimit(3...6)
            .textFieldStyle(.roundedBorder)
        }
      }
      .disabled(!manager.aiRenamingEnabled)

      Section("Options") {
        VStack(alignment: .leading) {
          HStack {
            Text("Max filename length")
            Spacer()
            Text("\(manager.maxFilenameLength)")
              .foregroundColor(.secondary)
              .monospacedDigit()
          }
          Slider(
            value: Binding(
              get: { Double(manager.maxFilenameLength) },
              set: { manager.maxFilenameLength = Int($0) }
            ),
            in: 20...200,
            step: 10
          )
        }
      }
      .disabled(!manager.aiRenamingEnabled)
    }
    .formStyle(.grouped)
    .task {
      selectedProvider = manager.providerType
      selectedPreset = manager.preset
      selectedModel = manager.openaiModel
      apiKeyInput = manager.apiKey(for: selectedProvider)
    }
  }
}
