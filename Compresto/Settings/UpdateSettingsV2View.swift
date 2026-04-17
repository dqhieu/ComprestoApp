//
//  UpdateSettingsV2View.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 12/21/24.
//

import SwiftUI

#if SPARKLE
import Sparkle

struct UpdateSettingsV2View: View {

  @EnvironmentObject var installationManager: InstallationManager

  private let updater: SPUUpdater
  @AppStorage("automaticallyChecksForUpdates") var automaticallyChecksForUpdates = true
  @AppStorage("shouldShowOnboardingV2") var shouldShowOnboardingV2 = true

  init(updater: SPUUpdater) {
    self.updater = updater
  }

  var body: some View {
    Form {
      Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
        .onChange(of: automaticallyChecksForUpdates) { newValue in
          Updater.shared.automaticallyChecksForUpdates = newValue
        }
      HStack {
        Text("Current version: \(appVersion)")
        Spacer()
        Button {
          if LicenseManager.shared.isValid {
            checkForUpdates()
          } else {
            let alert = NSAlert.init()
            alert.addButton(withTitle: "OK")
            alert.messageText = "Please activate your license to check for updates"
            let _ = alert.runModal()
          }
        } label: {
          Text("Check for Updates")
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .formStyle(.grouped)
    .scrollDisabled(true)
  }

  func checkForUpdates() {
    if LicenseManager.shared.licenseKey.lowercased().contains("macked") {
      showCrackedAlert(promoCode: "MACKED50")
    } else {
      updater.checkForUpdates()
    }
  }
}
#endif
