//
//  GeneralSettingsV2View.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 12/21/24.
//

import SwiftUI
import LaunchAtLogin
import UserNotifications
import KeyboardShortcuts
import TelemetryDeck

struct GeneralSettingsV2View: View {

  @AppStorage("showMenuBarIcon") var showMenuBarIcon = true
  @AppStorage("showDockIcon") var showDockIcon = true
  @AppStorage("sleepWhenFinish") var sleepWhenFinish = false
  @AppStorage("showMainWindowAtLaunch") var showMainWindowAtLaunch = true
  @AppStorage("pinMainWindowOnTop") var pinMainWindowOnTop = false
  @AppStorage("shareAnonymousAnalytics") var shareAnonymousAnalytics = true
  @State private var showLogViewer = false

  var body: some View {
    Form {
      LaunchAtLogin.Toggle()
      Toggle("Put computer to sleep when finish compressing", isOn: $sleepWhenFinish)
        .toggleStyle(.switch)
      Toggle(isOn: $showDockIcon) {
        Text("Show Dock icon")
      }
      .onChange(of: showDockIcon, perform: { newValue in
        if newValue {
          NSApp.setActivationPolicy(.regular)
        } else {
          NSApp.setActivationPolicy(.accessory)
        }
      })
      Toggle(isOn: $showMenuBarIcon) {
        Text("Show Menu Bar icon")
      }
      Toggle(isOn: $showMainWindowAtLaunch) {
        Text("Show main window at launch")
      }
      KeyboardShortcuts.Recorder("Show main window shortcut", name: .showMainWindow)
      VStack {
        Toggle(isOn: $pinMainWindowOnTop) {
          Text("Pin main window on top")
        }
        KeyboardShortcuts.Recorder("Toggle shortcut", name: .togglePinMainWindowOnTop)
      }
      Toggle("Share anonymous analytics", isOn: $shareAnonymousAnalytics)
        .toggleStyle(.switch)
        .onChange(of: shareAnonymousAnalytics, perform: { value in
          telemetryConfiguration.analyticsDisabled = !value
        })
//      HStack {
//        Text("Debug log")
//        Spacer()
//        Button {
//          let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("compresto.log")
//          NSWorkspace.shared.activateFileViewerSelecting([logURL])
//        } label: {
//          Text("Show in finder")
//        }
//        Button {
//          showLogViewer = true
//        } label: {
//          Text("View log")
//        }
//
//      }
    }
    .formStyle(.grouped)
    .scrollDisabled(true)
    .sheet(isPresented: $showLogViewer) {
      LogViewerView()
    }
  }

}

struct LogViewerView: View {
  @State private var logContent = ""
  @State private var isLoading = true
  @State private var showClearConfirmation = false
  @Environment(\.dismiss) var dismiss
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Text("Debug Log")
          .font(.headline)
        Spacer()
        Button("Copy") {
          let pasteboard = NSPasteboard.general
          pasteboard.clearContents()
          pasteboard.setString(logContent, forType: .string)
        }
        .disabled(isLoading || logContent.isEmpty)
        Button("Clear") {
          showClearConfirmation = true
        }
        .disabled(isLoading || logContent.isEmpty)
        Button("Close") {
          dismiss()
        }
      }
      .padding()
      .background(Color(NSColor.windowBackgroundColor))
      
      Divider()
      
      // Content
      if isLoading {
        ProgressView("Loading log...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        TextEditor(text: .constant(logContent))
          .font(.system(.caption, design: .monospaced))
          .padding(8)
          .background(Color(NSColor.textBackgroundColor))
      }
    }
    .frame(minWidth: 600, minHeight: 400)
    .task {
      loadLogContent()
    }
    .alert("Clear Log", isPresented: $showClearConfirmation) {
      Button("Cancel", role: .cancel) { }
      Button("Clear", role: .destructive) {
        clearLog()
      }
    } message: {
      Text("Are you sure you want to clear the debug log? This action cannot be undone.")
    }
  }
  
  private func loadLogContent() {
    isLoading = true
    DispatchQueue.global(qos: .userInitiated).async {
      let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("compresto.log")
      
      do {
        let content = try String(contentsOf: logURL, encoding: .utf8)
        DispatchQueue.main.async {
          self.logContent = content.isEmpty ? "No log entries found." : content
          self.isLoading = false
        }
      } catch {
        DispatchQueue.main.async {
          self.logContent = "Error reading log file: \(error.localizedDescription)"
          self.isLoading = false
        }
      }
    }
  }
  
  private func clearLog() {
    DispatchQueue.global(qos: .userInitiated).async {
      let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("compresto.log")
      
      do {
        try "".write(to: logURL, atomically: true, encoding: .utf8)
        DispatchQueue.main.async {
          self.logContent = "No log entries found."
        }
      } catch {
        DispatchQueue.main.async {
          // If clearing fails, just show an error message but don't change the current content
          print("Failed to clear log: \(error.localizedDescription)")
        }
      }
    }
  }
}
