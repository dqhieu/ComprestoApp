//
//  Updater.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 12/21/24.
//

import SwiftUI
#if SPARKLE
import Sparkle

class Updater: NSObject, SPUUpdaterDelegate {

  @AppStorage("automaticallyChecksForUpdates") var automaticallyChecksForUpdates = true

  static let shared = Updater()

  var updater: SPUUpdater?
  var didFindValidUpdate = false

  var dispatchWorkItem: DispatchWorkItem?

  func checkForUpdates() {
    if LicenseManager.shared.licenseKey.lowercased().contains("macked") {
      showCrackedAlert(promoCode: "MACKED50")
      return
    }
    dispatchWorkItem?.cancel()
    dispatchWorkItem = DispatchWorkItem(block: { [weak self] in
      self?.checkForUpdates()
    })
    if automaticallyChecksForUpdates {
      DispatchQueue.main.asyncAfter(deadline: .now() + 60 * 60 * 24, execute: dispatchWorkItem!)
    }
    updater?.checkForUpdateInformation()
  }

  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    DispatchQueue.main.async { [weak self] in
      if self?.updater?.canCheckForUpdates ?? false {
        self?.updater?.checkForUpdates()
      } else {
        self?.didFindValidUpdate = true
      }
    }
  }

  func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
    DispatchQueue.main.async { [weak self] in
      if self?.didFindValidUpdate ?? false, self?.updater?.canCheckForUpdates ?? false {
        self?.updater?.checkForUpdates()
      }
      self?.didFindValidUpdate = false
    }
  }

}
#endif
