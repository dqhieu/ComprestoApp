//
//  SettingsV2View.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 12/21/24.
//

import SwiftUI

#if SPARKLE
import Sparkle
#endif

enum Setting: String, CaseIterable, Identifiable {
  case general
  case presets
  case advanced
  case fileManagement
  case appearance
  case monitoring
  case dropZone
  case pdfCompression
  case aiRenaming
  case license
  case credits
  case softwareUpdate
  case about

  var id: String { rawValue }

  var displayText: String {
    switch self {
    case .general:
      return "General"
    case .presets:
      return "Presets"
    case .advanced:
      return "Advanced"
    case .fileManagement:
      return "File Management"
    case .appearance:
      return "Appearance"
    case .softwareUpdate:
      return "Software Update"
    case .monitoring:
      return "Folder Monitoring"
    case .dropZone:
      return "Drop Zone"
    case .pdfCompression:
      return "PDF Compression"
    case .aiRenaming:
      return "AI Renaming"
    case .license:
      return "License"
    case .credits:
      return "Credits"
    case .about:
      return "About"
    }
  }

  var symbolName: String {
    switch self {
    case .general:
      return "gearshape"
    case .presets:
      return "slider.horizontal.below.square.and.square.filled"
    case .advanced:
      return "slider.horizontal.3"
    case .fileManagement:
      return "doc.badge.gearshape"
    case .appearance:
      return "wand.and.stars"
    case .softwareUpdate:
      return "arrow.triangle.2.circlepath.circle"
    case .monitoring:
      return "folder"
    case .dropZone:
      return "doc.viewfinder"
    case .pdfCompression:
      return "doc.append"
    case .aiRenaming:
      return "sparkles"
    case .license:
      return "key"
    case .credits:
      return "c.circle"
    case .about:
      return "info.circle"
    }
  }

  static var allSettings: [Setting] {
    #if SETAPP
    return allCases.filter({ $0 != .softwareUpdate && $0 != .aiRenaming })
    #endif
    return allCases
  }
}

struct SettingsV2View: View {

  @EnvironmentObject var installationManager: InstallationManager
  @State private var currentSetting: Setting = .general
  @State private var hoveringSetting: Setting?

  static let navigateToSettingNotification = Notification.Name("navigateToSetting")

  #if SPARKLE
  private let updater: SPUUpdater

  init(updater: SPUUpdater) {
    self.updater = updater
  }
  #endif
  #if SETAPP
  init() {}
  #endif

  var body: some View {
    macOS26Content
      .onReceive(NotificationCenter.default.publisher(for: SettingsV2View.navigateToSettingNotification)) { notification in
        if let setting = notification.object as? Setting {
          currentSetting = setting
        }
      }
  }

  var macOS26Content: some View {
    NavigationSplitView {
      List(selection: $currentSetting) {
        ForEach(Setting.allSettings) { setting in
          NavigationLink(value: setting) {
            Group {
              if #available(macOS 15.0, *) {
                Image(systemName: setting.symbolName)
                  .symbolEffect(.bounce.byLayer, options: .nonRepeating, isActive: currentSetting == setting)
                  .frame(width: 16, height: 16, alignment: .center)
              } else {
                Image(systemName: setting.symbolName)
                  .frame(width: 16, height: 16, alignment: .center)
              }
              Text(setting.displayText)
            }
            .padding(.leading, 8)
          }
        }
      }
      .navigationTitle("Settings")
    } detail: {
      Group {
        switch currentSetting {
        case .general:
          GeneralSettingsV2View()
        case .presets:
          PresetSettingsView()
        case .advanced:
          AdvancedSettingsV2View()
        case .fileManagement:
          FileManagementSettingsView()
        case .appearance:
          AppearanceSettingsV2View()
        case .monitoring:
          MonitoringSettingsView()
        case .dropZone:
          DropZoneSettingsV2View()
        case .pdfCompression:
          PDFCompressionSettingsView()
            .environmentObject(installationManager)
        case .aiRenaming:
          AIRenamingSettingsView()
        case .license:
          LicenseSettingsV2View()
        case .credits:
          CreditsSettingsView()
        case .softwareUpdate:
          #if SPARKLE
          UpdateSettingsV2View(updater: updater)
          #endif
        case .about:
          AboutSettingsView()
        }
      }
      .navigationTitle(currentSetting.displayText)
      .frame(minWidth: 300)
    }
  }

}

struct SettingsViewModifier: ViewModifier {
  func body(content: Content) -> some View {
    if #available(macOS 14, *) {
      content
        .background(SettingsWindowConfigurator())
    } else {
      content
    }
  }
}
