//
//  MenuBarView.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 12/8/24.
//

import SwiftUI
import SettingsAccess

struct MenuBarView: View {

  @Environment(\.openWindow) var openWindow
  @AppStorage("showDockIcon") var showDockIcon = true

  var body: some View {
      Button {
        openWindow(id: "mainWindow")
        if showDockIcon {
          NSApp.setActivationPolicy(.regular)
        } else {
          NSApp.setActivationPolicy(.accessory)
        }
        NSApp.activate(ignoringOtherApps: true)
        NSApp.keyWindow?.makeKeyAndOrderFront(nil)
      } label: {
        Text("Main Window")
      }
      .keyboardShortcut("M")
      Button {
        openWindow(id: "compressionHistory")
        if showDockIcon {
          NSApp.setActivationPolicy(.regular)
        } else {
          NSApp.setActivationPolicy(.accessory)
        }
        NSApp.activate(ignoringOtherApps: true)
        NSApp.keyWindow?.makeKeyAndOrderFront(nil)
      } label: {
        Text("History")
      }
      .keyboardShortcut("Y")
    Button {
      openWindow(id: "feedback-board")
      if showDockIcon {
        NSApp.setActivationPolicy(.regular)
      } else {
        NSApp.setActivationPolicy(.accessory)
      }
      NSApp.activate(ignoringOtherApps: true)
      NSApp.keyWindow?.makeKeyAndOrderFront(nil)
    } label: {
      Text("Feedback Board")
    }
    .keyboardShortcut("B")
    Button {
      openWindow(id: "settings")
      if showDockIcon {
        NSApp.setActivationPolicy(.regular)
      } else {
        NSApp.setActivationPolicy(.accessory)
      }
      NSApp.activate(ignoringOtherApps: true)
      NSApp.keyWindow?.makeKeyAndOrderFront(nil)
    } label: {
      Text("Settings")
    }
    .keyboardShortcut(",")
    Button("Quit") {
      NSApp.terminate(nil)
    }
    .keyboardShortcut("Q")
  }
}
