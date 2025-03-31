//
//  AppearanceSettingsV2View.swift
//  CompressX
//
//  Created by Dinh Quang Hieu on 12/21/24.
//

import SwiftUI
import TelemetryClient

enum NotchStyle: String, CaseIterable {
  case none
  case compact
  case expanded

  var displayText: String {
    switch self {
    case .none:
      return "None"
    case .compact:
      return "Compact"
    case .expanded:
      return "Expanded"
    }
  }
}

enum MenuBarIconStyle: String, CaseIterable {
  case sameAsDock
  case simple

  var displayText: String {
    switch self {
    case .sameAsDock:
      return "Same as dock"
    case .simple:
      return "Simple"
    }
  }
}

struct AppearanceSettingsV2View: View {

  @AppStorage("selectedAppIconName") var selectedAppIconName = "AppIcon"
  @AppStorage("notchStyle") var notchStyle: NotchStyle = .expanded
  @AppStorage("menuBarIconStyle") var menuBarIconStyle: MenuBarIconStyle = .sameAsDock
  @AppStorage("confettiEnabled") var confettiEnabled = false

  var body: some View {
    Form {
      Section {
        Picker(selection: $notchStyle) {
          ForEach(NotchStyle.allCases, id: \.self) { style in
            Text(style.displayText).tag(style.rawValue)
          }
        } label: {
          Text("Dynamic island style")
        }
        .onChange(of: notchStyle) { newValue in
          NotchKit.shared.close()
          if newValue == .expanded || newValue == .compact {
            NotchKit.shared.show(folderPath: "", notchStyle: newValue, dismissDelay: 3)
          }
        }
        Toggle(isOn: $confettiEnabled) {
          VStack(alignment: .leading) {
            Text("Show confetti when compression finishes")
            Text("Requires [Raycast](https://www.raycast.com/) to be installed. [Read the docs](https://docs.compresto.app/guides/how-to-show-confetti-when-compression-finishes) or [test confetti](raycast://confetti)")
              .foregroundStyle(.secondary)
              .font(.caption)
          }
        }
        .onChange(of: confettiEnabled) { newValue in
          if newValue, let url = URL(string: "raycast://confetti"), let _ = NSWorkspace.shared.urlForApplication(toOpen: url) {
            NSWorkspace.shared.open(url)
          } else {
            confettiEnabled = false
          }
        }
        Picker(selection: $menuBarIconStyle) {
          ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
            Text(style.displayText).tag(style.rawValue)
          }
        } label: {
          Text("Menu bar icon style")
        }
      }
      Section {
        LazyVGrid(columns: [
          GridItem(.flexible()),
          GridItem(.flexible())
        ], alignment: .leading) {
          IconView(iconName: "AppIcon",
                   displayName: "Original",
                   twitterHandle: nil,
                   selectedIconName: selectedAppIconName) {
            if let iconImage = NSImage(named: "AppIcon") {
              changeIcon(iconImage: iconImage, iconName: "AppIcon")
            }
          }

          IconView(iconName: "CompressXBlue",
                   displayName: "Blue",
                   twitterHandle: nil,
                   selectedIconName: selectedAppIconName) {
            if let iconImage = NSImage(named: "CompressXBlue") {
              changeIcon(iconImage: iconImage, iconName: "CompressXBlue")
            }
          }

          IconView(iconName: "CompressX-alohe-light",
                   displayName: "Alohe Light",
                   twitterHandle: "alemalohe",
                   selectedIconName: selectedAppIconName) {
            if let iconImage = NSImage(named: "CompressX-alohe-light") {
              changeIcon(iconImage: iconImage, iconName: "CompressX-alohe-light")
            }
          }

          IconView(iconName: "CompressX-alohe-dark",
                   displayName: "Alohe Dark",
                   twitterHandle: "alemalohe",
                   selectedIconName: selectedAppIconName) {
            if let iconImage = NSImage(named: "CompressX-alohe-dark") {
              changeIcon(iconImage: iconImage, iconName: "CompressX-alohe-dark")
            }
          }

          IconView(iconName: "CompressX-Kacper",
                   displayName: "Kacper",
                   twitterHandle: "kacperfyi",
                   selectedIconName: selectedAppIconName) {
            if let iconImage = NSImage(named: "CompressX-Kacper") {
              changeIcon(iconImage: iconImage, iconName: "CompressX-Kacper")
            }
          }
        }
      } header: {
        Text("Dock Icon")
      }
    }
    .formStyle(.grouped)
    .scrollDisabled(true)
  }

  func changeIcon(iconImage: NSImage, iconName: String) {
    TelemetryDeck.signal("compress.dockIcon.change", parameters: [
      "iconName": iconName,
    ])
    selectedAppIconName = iconName
    changeAppIcon(image: iconImage)
  }
}
