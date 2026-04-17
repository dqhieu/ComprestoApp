//
//  AboutSettingsView.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 12/21/24.
//

import SwiftUI

struct AboutSettingsView: View {

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var installationManager: InstallationManager
  @AppStorage("shouldShowOnboardingV2") var shouldShowOnboardingV2 = true

  var body: some View {
    Form {
      HStack {
        Text("Website")
        Spacer()
        Link(destination: URL(string: "https://compresto.app")!) {
          HStack {
            Text("compresto.app")
            Image(systemName: "arrow.up.right.square")
          }
        }
      }
      HStack {
        Text("Changelog")
        Spacer()
        Link(destination: URL(string: "https://compresto.app/changelog")!) {
          HStack {
            Text("compresto.app/changelog")
            Image(systemName: "arrow.up.right.square")
          }
        }
      }
      HStack {
        Text("Documentation")
        Spacer()
        Link(destination: URL(string: "https://compresto.app/docs")!) {
          HStack {
            Text("compresto.app/docs")
            Image(systemName: "arrow.up.right.square")
          }
        }
      }
      HStack {
        Text("Support email")
        Spacer()
        Link(destination: URL(string: "mailto:hieu@compresto.app")!) {
          HStack {
            Text("hieu@compresto.app")
            Image(systemName: "arrow.up.right.square")
          }
        }
      }
      HStack {
        Text("𝕏")
        Spacer()
        Link(destination: URL(string: "https://x.com/ComprestoApp")!) {
          HStack {
            Text("x.com/ComprestoApp")
            Image(systemName: "arrow.up.right.square")
          }
        }
      }
      HStack {
        Text("Telegram")
        Spacer()
        Link(destination: URL(string: "https://t.me/+ldb3DRPCi6Y1NWNl")!) {
          HStack {
            Text("t.me/+ldb3DRPCi6Y1NWNl")
            Image(systemName: "arrow.up.right.square")
          }
        }
      }
      HStack {
        Text("Github")
        Spacer()
        Link(destination: URL(string: "https://github.com/dqhieu/ComprestoApp")!) {
          HStack {
            Text("github.com/dqhieu/ComprestoApp")
            Image(systemName: "arrow.up.right.square")
          }
        }
      }
      HStack {
        Text("Raycast extension")
        Spacer()
        Link(destination: URL(string: "https://www.raycast.com/hieudinh/compressx")!) {
          HStack {
            Text("raycast.com/hieudinh/compressx")
            Image(systemName: "arrow.up.right.square")
          }
        }
      }
      HStack {
        Text("App version")
        Spacer()
        Text(appVersion)
      }
      HStack {
        Spacer()
        Button {
          installationManager.removeDependencies()
          installationManager.state = .idle
          shouldShowOnboardingV2 = true
          dismiss()
          NSApp.keyWindow?.setContentSize(NSSize(width: 400, height: 300))
        } label: {
          Text("Clear cache and reset onboarding")
        }
        .buttonStyle(.bordered)
        Spacer()
      }
    }
    .formStyle(.grouped)
  }
}
