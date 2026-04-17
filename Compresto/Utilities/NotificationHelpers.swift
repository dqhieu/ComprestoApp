//
//  NotificationHelpers.swift
//  Compresto
//

import Foundation
import AppKit
import UserNotifications

func sendSuccessPushNotification(path: String, count: Int, urls: [String]) {
  let content = UNMutableNotificationContent()
  content.title = "Compression finished 🎉"
  if urls.count > 1 {
    content.body = "\(count) files saved to \(path). Tap to open them in Finder"
  } else {
    content.body = "\(count) file saved to \(path). Tap to open them in Finder"
  }
  content.userInfo = ["fileURLs": urls]
  content.sound = .default
  let request = UNNotificationRequest(identifier: "compress.finish." + UUID().uuidString, content: content, trigger: nil)
  Task {
    try? await UNUserNotificationCenter.current().add(request)
  }
}

func sendErrorPushNotification(error: String) {
  let content = UNMutableNotificationContent()
  content.title = "Compression failed ❌"
  content.body = error
  content.sound = .default
  let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
  Task {
    try? await UNUserNotificationCenter.current().add(request)
  }
}

func showCompressionFailedAlert(error: String, hasPDFInput: Bool = false) {
  let alert = NSAlert()
  alert.messageText = "Compression failed"
  alert.alertStyle = .critical
  if hasPDFInput {
    alert.informativeText = error + "\n\nGhostscript is required for PDF compression. If you haven't set it up yet, check out our guide."
    alert.addButton(withTitle: "Open Guide")
    alert.addButton(withTitle: "OK")
    if alert.runModal() == .alertFirstButtonReturn {
      NSWorkspace.shared.open(URL(string: "https://compresto.app/docs/guides/getting-started/install-ghostscript")!)
    }
  } else {
    alert.informativeText = error
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }
}

func showActivateLicenseAlert() {
  let alert = NSAlert.init()
  alert.messageText = "Please activate your license"
  alert.alertStyle = .critical
  alert.addButton(withTitle: "OK")
  let _ = alert.runModal()
}

func showActiveLicenseNotification() {
  let content = UNMutableNotificationContent()
  content.title = "License not activated!"
  content.body = "Please activate your license to use this feature!"
  content.sound = .default
  let request = UNNotificationRequest(identifier: "compress.activation.error" + UUID().uuidString, content: content, trigger: nil)
  Task {
    try? await UNUserNotificationCenter.current().add(request)
  }
}

func showCrackedAlert(promoCode: String) {
  let alert = NSAlert()
  alert.messageText = "👀 Psst… That's Not the Real Me"
  alert.informativeText = "Looks like you might be using a \u{201C}special\u{201D} copy of Compresto.\n\nSure, it's free… but so are computer viruses and mysterious background processes you never asked for.\n\nLet's make a deal - grab the real, safe, fully-supported version for 50% off.\n\nNo malware. No drama. Just all the features, updates, and a happy computer.\n\nHere is your promo code:\n\(promoCode)"
  alert.addButton(withTitle: "Copy Code and Join the Clean Side")
  let response = alert.runModal()
  switch response {
  case .alertFirstButtonReturn:
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(promoCode, forType: .string)
    if let url = URL(string: "https://compresto.app/pricing") {
      NSWorkspace.shared.open(url)
    }
    NSApplication.shared.terminate(nil)
  default:
    NSApplication.shared.terminate(nil)
    break
  }
}
