//
//  NotchKit.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 01/03/2024.
//

import SwiftUI
#if SETAPP
import Setapp
#endif

class NotchKit {

  static let WIDTH: CGFloat = 354
  static var HEIGHT: CGFloat {
    if #available(macOS 26, *) {
      return 100
    } else {
      return 87
    }
  }

  var workItem: DispatchWorkItem?

  static var shared = NotchKit()

  var notchWindow: NSWindow?
  var notchView: NotchView?

  func show(folderPath: String, notchStyle: NotchStyle, dismissDelay: TimeInterval? = nil) {
    #if SETAPP
    SetappManager.shared.reportUsageEvent(.userInteraction)
    #endif
    let frame = NSRect(
      x: ((NSScreen.main?.frame.width ?? 0) - NotchKit.WIDTH) / 2 + (NSScreen.main?.frame.origin.x ?? 0),
      y: (NSScreen.main?.frame.height ?? 0) + (NSScreen.main?.frame.origin.y ?? 0) - 100,
      width: NotchKit.WIDTH,
      height: 100
    )
    if self.notchWindow != nil {
      notchWindow?.setFrameOrigin(frame.origin)
      return
    }
    let window = NSWindow()
    let onClose: () -> Void = { [weak self] in
      self?.close()
    }
    let notchView = NotchView(
      hasNotch: hasNotch,
      folderPath: folderPath,
      onClose: onClose,
      notchStyle: notchStyle,
      dismissDelay: dismissDelay
    )
    let view = NSHostingView(rootView: notchView)
    window.contentView = view
    window.level = .popUpMenu
    window.backgroundColor = NSColor.clear
    window.styleMask = [.borderless]
    window.backingType = .buffered
    window.setFrame(frame, display: true)
    window.orderFront(nil)
    window.isReleasedWhenClosed = false
    self.notchWindow = window
    self.notchView = notchView
  }

  func dismiss() {
    notchView?.dismiss()
  }

  func close() {
    notchWindow?.contentView = nil
    notchWindow?.close()
    notchWindow = nil
    notchView = nil
  }
}
