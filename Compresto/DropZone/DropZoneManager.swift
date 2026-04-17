  //
  //  DropZoneManager.swift
  //  Compresto
  //
  //  Created by Dinh Quang Hieu on 4/9/24.
  //

import AppKit
import SwiftUI
import Combine

enum DropZoneSide {
  case compress
  case open
}

class DropZoneManager: ObservableObject {

  @AppStorage("outputFileNameFormat") var outputFileNameFormat = ""
  @AppStorage("notchStyle") var notchStyle: NotchStyle = .expanded
  @AppStorage("dropZoneEnabled") var dropZoneEnabled = true
  @AppStorage("dropZoneMode") var dropZoneMode: DropZoneMode = .compress

  @AppStorage("dropZoneCompressionSettingsType") var dropZoneCompressionSettingsType = DropZoneCompressSettingsType.same
  @AppStorage("dropZonePresetId") var dropZonePresetId: String = ""

  @AppStorage("dropZoneImageQuality") var dropZoneImageQuality: ImageQuality = .good
  @AppStorage("dropZoneImageFormat") var dropZoneImageFormat: ImageFormat = .same
  @AppStorage("dropZoneImageSize") var dropZoneImageSize: ImageSize = .same
  @AppStorage("dropZoneImageSizeValue") var dropZoneImageSizeValue = 100
  @AppStorage("dropZoneVideoQuality") var dropZoneVideoQuality: VideoQuality = .good
  @AppStorage("dropZoneVideoFormat") var dropZoneVideoFormat: VideoFormat = .same
  @AppStorage("dropZoneVideoDimension") var dropZoneVideoDimension: VideoDimension = .same
  @AppStorage("dropZoneVideoDimensionValue") var dropZoneVideoDimensionValue: Int = 1920
  @AppStorage("dropZoneRemoveAudio") var dropZoneRemoveAudio: Bool = true
  @AppStorage("dropZonePreserveTransparency") var dropZonePreserveTransparency: Bool = false
  @AppStorage("dropZoneGifQuality") var dropZoneGifQuality: VideoQuality = .good
  @AppStorage("dropZoneGifDimension") var dropZoneGifDimension: GifDimension = .same
  @AppStorage("dropZoneOutputFolder") var dropZoneOutputFolder: OutputFolder = .same
  @AppStorage("dropZoneCustomOutputFolder") var dropZoneCustomOutputFolder: String = ""
  @AppStorage("dropZoneRemoveFileAfterCompression") var dropZoneRemoveFileAfterCompression: Bool = false
  @AppStorage("dropZonePdfQuality") var dropZonePdfQuality: PDFQuality = .balance
  @AppStorage("dropZoneNestedFolderName") var dropZoneNestedFolderName = "compressed"
  @AppStorage("ghostscriptPath") var ghostscriptPath = ""

  @AppStorage("imageQuality") var defaultImageQuality: ImageQuality = .highest
  @AppStorage("outputImageFormat") var defaultImageFormat: ImageFormat = .same
  @AppStorage("imageSize") var defaultImageSize: ImageSize = .same
  @AppStorage("imageSizeValue") var defaultImageSizeValue = 100

  @AppStorage("videoQuality") var defaultVideoQuality: VideoQuality = .high
  @AppStorage("outputFormat") var defaultVideoFormat: VideoFormat = .same
  @AppStorage("videoDimension") var defaultVideoDimension: VideoDimension = .same
  @AppStorage("videoDimensionValue") var defaultVideoDimensionValue: Int = 1920
  @AppStorage("removeAudio") var defaultRemoveAudio = false
  @AppStorage("gifQuality") var defaultGifQuality: VideoQuality = .high
  @AppStorage("gifDimension") var defaultGifDimension: GifDimension = .same
  @AppStorage("pdfQuality") var defaultPdfQuality: PDFQuality = .balance
  @AppStorage("outputFolder") var defaultOutputFolder: OutputFolder = .same
  @AppStorage("customOutputFolder") var defaultCustomOutputFolder = ""
  @AppStorage("removeFileAfterCompress") var defaultRemoveFileAfterCompress = false
  @AppStorage("nestedFolderName") var defaultNestedFolderName = "compressed"

  private var presetOrNil: CompressionPreset? {
    PresetManager.shared.preset(for: dropZonePresetId)
  }

  var imageQuality: ImageQuality {
    switch dropZoneCompressionSettingsType {
      case .same: return defaultImageQuality
      case .custom: return dropZoneImageQuality
      case .preset: return presetOrNil?.imageQuality ?? defaultImageQuality
    }
  }

  var imageFormat: ImageFormat {
    switch dropZoneCompressionSettingsType {
      case .same: return defaultImageFormat
      case .custom: return dropZoneImageFormat
      case .preset: return presetOrNil?.imageFormat ?? defaultImageFormat
    }
  }

  var imageSize: ImageSize {
    switch dropZoneCompressionSettingsType {
      case .same: return defaultImageSize
      case .custom: return dropZoneImageSize
      case .preset: return presetOrNil?.imageSize ?? defaultImageSize
    }
  }

  var imageSizeValue: Int {
    switch dropZoneCompressionSettingsType {
      case .same: return defaultImageSizeValue
      case .custom: return dropZoneImageSizeValue
      case .preset: return presetOrNil?.imageSizeValue ?? defaultImageSizeValue
    }
  }

  var gifQuality: VideoQuality {
    switch dropZoneCompressionSettingsType {
      case .same: return defaultGifQuality
      case .custom: return dropZoneGifQuality
      case .preset: return presetOrNil?.gifQuality ?? defaultGifQuality
    }
  }

  var gifDimension: GifDimension {
    switch dropZoneCompressionSettingsType {
      case .same: return defaultGifDimension
      case .custom: return dropZoneGifDimension
      case .preset: return presetOrNil?.gifDimension ?? defaultGifDimension
    }
  }

  var videoQuality: VideoQuality {
    switch dropZoneCompressionSettingsType {
      case .same: return defaultVideoQuality
      case .custom: return dropZoneVideoQuality
      case .preset: return presetOrNil?.videoQuality ?? defaultVideoQuality
    }
  }

  var videoFormat: VideoFormat {
    switch dropZoneCompressionSettingsType {
      case .same: return defaultVideoFormat
      case .custom: return dropZoneVideoFormat
      case .preset: return presetOrNil?.videoFormat ?? defaultVideoFormat
    }
  }

  var videoDimension: VideoDimension {
    switch dropZoneCompressionSettingsType {
      case .same: return defaultVideoDimension
      case .custom: return dropZoneVideoDimension
      case .preset: return presetOrNil?.videoDimension ?? defaultVideoDimension
    }
  }

  var videoDimensionValue: Int {
    switch dropZoneCompressionSettingsType {
      case .same: return defaultVideoDimensionValue
      case .custom: return dropZoneVideoDimensionValue
      case .preset: return presetOrNil?.videoDimensionValue ?? defaultVideoDimensionValue
    }
  }

  var removeAudio: Bool {
    switch dropZoneCompressionSettingsType {
      case .same: return defaultRemoveAudio
      case .custom: return dropZoneRemoveAudio
      case .preset: return presetOrNil?.removeAudio ?? defaultRemoveAudio
    }
  }

  var outputFolder: OutputFolder {
    switch dropZoneCompressionSettingsType {
      case .same: return defaultOutputFolder
      case .custom: return dropZoneOutputFolder
      case .preset: return defaultOutputFolder
    }
  }

  var customOutputFolder: String {
    switch dropZoneCompressionSettingsType {
      case .same: return defaultCustomOutputFolder
      case .custom: return dropZoneCustomOutputFolder
      case .preset: return defaultCustomOutputFolder
    }
  }

  var nestedFolderName: String {
    switch dropZoneCompressionSettingsType {
      case .same: return defaultNestedFolderName
      case .custom: return dropZoneNestedFolderName
      case .preset: return defaultNestedFolderName
    }
  }

  var removeFileAfterCompression: Bool {
    switch dropZoneCompressionSettingsType {
      case .same: return defaultRemoveFileAfterCompress
      case .custom: return dropZoneRemoveFileAfterCompression
      case .preset: return defaultRemoveFileAfterCompress
    }
  }

  var pdfQuality: PDFQuality {
    switch dropZoneCompressionSettingsType {
      case .same: return defaultPdfQuality
      case .custom: return dropZonePdfQuality
      case .preset: return presetOrNil?.pdfQuality ?? defaultPdfQuality
    }
  }

  var leftMouseDragMonitor: Any?
  var lastPasteboardChangeCount: Int = NSPasteboard(name: .drag).changeCount
  private let offsetUpdateSubject = PassthroughSubject<Void, Never>()

  static let shared = DropZoneManager()

  static var isSplitMode: Bool {
    DropZoneMode(rawValue: UserDefaults.standard.string(forKey: "dropZoneMode") ?? "") == .compressAndOpen
  }

  static var WIDTH: CGFloat {
    isSplitMode ? 360 : 260
  }

  static var HEIGHT: CGFloat {
    let extraHeight: CGFloat = isSplitMode ? (hasNotch ? 40 : 20) : 0
    if #available(macOS 26, *) {
      if hasNotch {
        return 80 + extraHeight
      }
      return 60 + extraHeight
    } else {
      if hasNotch {
        return 70 + extraHeight
      }
      return 50 + extraHeight
    }
  }

  var notchWindow: NSWindow?

  var model = DropZoneViewModel()

  init() {
    if dropZoneEnabled {
      enableDropZone()
    }
  }

  func getScreenWithMouse() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    let screens = NSScreen.screens
    let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) })

    return screenWithMouse
  }

  private var notchTopCenterPoint: CGPoint {
    return CGPoint(
      x: (NSScreen.main?.frame.width ?? 0) / 2 + (NSScreen.main?.frame.origin.x ?? 0),
      y: (NSScreen.main?.frame.height ?? 0) + (NSScreen.main?.frame.origin.y ?? 0)
    )
  }

  private var notchFrame: NSRect {
    return NSRect(
      x: notchTopCenterPoint.x - DropZoneManager.WIDTH/2,
      y: notchTopCenterPoint.y - DropZoneManager.HEIGHT,
      width: DropZoneManager.WIDTH,
      height: DropZoneManager.HEIGHT
    )
  }

  func show() {
    if self.notchWindow != nil {
      notchWindow?.setFrameOrigin(notchFrame.origin)
      return
    }
    let window = NSWindow()
    let onClose: () -> Void = { [weak self] in
      self?.close()
    }
    let notchView = DropZoneView(
      model: model,
      onClose: onClose
    )
    let view = NSHostingView(rootView: notchView)
    window.contentView = view
    window.level = .popUpMenu
    window.backgroundColor = NSColor.clear
    window.styleMask = [.borderless]
    window.backingType = .buffered
    window.setFrame(notchFrame, display: true)
    window.orderFront(nil)
    window.isReleasedWhenClosed = false
    self.notchWindow = window
  }

  func close() {
    notchWindow?.contentView = nil
    notchWindow?.close()
    notchWindow = nil
  }

  var jobQueue: [Job] = []
  let jobQueuePublisher = PassthroughSubject<[Job], Never>()
  var cancellables = Set<AnyCancellable>()

  func queueJob(inputFileURLs: [URL]) {
    let resolvedFiles = flatten(urls: inputFileURLs, maxDepth: 1_000)

    for inputFileURL in resolvedFiles {
      let fileType = checkFileType(url: inputFileURL)
      let outputType: OutputType? = {
        switch fileType {
          case .image:
            return .image(
              imageQuality: imageQuality,
              imageFormat: imageFormat,
              imageSize: imageSize,
              imageSizeValue: imageSizeValue
            )
          case .gif:
            return .gifCompress(
              gifQuality: gifQuality,
              dimension: gifDimension
            )
          case .pdf:
            if ghostscriptPath.isEmpty {
              DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Ghostscript is not installed"
                alert.informativeText = "Ghostscript is required for PDF compression. If you haven't set it up yet, check out our guide."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open Guide")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn {
                  NSWorkspace.shared.open(URL(string: "https://compresto.app/docs/guides/getting-started/install-ghostscript")!)
                }
              }
              return nil
            }
            return .pdfCompress(pdfQuality: pdfQuality)
          case .video:
            return .video(
              videoQuality: videoQuality,
              videoDimension: videoDimension,
              videoDimensionValue: videoDimensionValue,
              videoFormat: videoFormat,
              targetFileSize: 0,
              hasAudio: true,
              removeAudio: removeAudio,
              preserveTransparency: false,
              startTime: nil,
              endTime: nil
            )
          default:
            return nil
        }
      }()
      guard let outputType = outputType else { return }
      let job = Job(
        inputFileURL: inputFileURL,
        outputType: outputType,
        outputFolder: outputFolder,
        customOutputFolder: customOutputFolder,
        nestedFolderName: nestedFolderName,
        outputFileNameFormat: outputFileNameFormat,
        removeInputFile: removeFileAfterCompression
      )

      jobQueue.append(job)
    }
    jobQueuePublisher.send(jobQueue)
  }

  func enableDropZone() {
    disableDropZone()

    let debouncedStream = jobQueuePublisher
      .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
      .eraseToAnyPublisher()

    debouncedStream
      .sink { jobs in
        guard jobs.count > 0 else { return }
        DispatchQueue.main.async { [weak self] in
          self?.jobQueue.removeAll()
          guard LicenseManager.shared.canCompress() else {
            return showActiveLicenseNotification()
          }
          if HUDJobManager.shared.isRunning {
            HUDJobManager.shared.queue(newJobs: jobs)
          } else {
            HUDJobManager.shared.jobs = jobs
            Task {
              await HUDJobManager.shared.compress()
            }
            let outputFolder = jobs.first?.outputFileURL.deletingLastPathComponent().path(percentEncoded: false) ?? ""
            if let style = self?.notchStyle, style != NotchStyle.none {
              NotchKit.shared.show(folderPath: outputFolder, notchStyle: style)
            }
          }
        }
      }
      .store(in: &cancellables)

    offsetUpdateSubject
      .throttle(for: .milliseconds(50), scheduler: RunLoop.main, latest: true)
      .sink { [weak self] in
        guard let self else { return }
        withAnimation {
          self.performOffsetCalculation()
        }
      }
      .store(in: &cancellables)

    if let monitor = leftMouseDragMonitor {
      NSEvent.removeMonitor(monitor)
    }
    leftMouseDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
      self?.checkForDraggedItems()
      self?.requestOffsetUpdate()
    }
  }

  let offsetXMax: CGFloat = 20
  let offsetYMax: CGFloat = 10
  @Published var offsetX: CGFloat = 0
  @Published var offsetY: CGFloat = 0
  @Published var hoveredSide: DropZoneSide? = nil

  private func requestOffsetUpdate() {
    offsetUpdateSubject.send()
  }

  private func performOffsetCalculation() {
    let mouseLocation = NSEvent.mouseLocation
    let centerPoint = notchTopCenterPoint
    let midY = (NSScreen.main?.frame.height ?? 0) / 2 + (NSScreen.main?.frame.origin.y ?? 0)
    offsetX = offsetXMax * ((mouseLocation.x - centerPoint.x) / centerPoint.x)
    offsetY = offsetYMax * ((mouseLocation.y - midY) / midY)
    let notchDropZoneFrame = NSRect(
      x: notchFrame.origin.x - 150,
      y: notchFrame.origin.y + (NSApplication.shared.mainMenu?.menuBarHeight ?? 0) - 300 + notchFrame.height,
      width: 300 + notchFrame.width,
      height: 300
    )

    if notchDropZoneFrame.contains(mouseLocation) {
      if !model.isShowing {
        model.show()
      }
      // Only highlight when mouse is inside the actual notch box
      if DropZoneManager.isSplitMode && notchFrame.contains(mouseLocation) {
        hoveredSide = mouseLocation.x < centerPoint.x ? .compress : .open
      } else {
        hoveredSide = nil
      }
    } else {
      if model.isShowing {
        model.hide()
      }
      hoveredSide = nil
    }
  }

  private func checkForDraggedItems() {
    let dragPasteboard = NSPasteboard(name: .drag)
    let currentChangeCount = dragPasteboard.changeCount
    guard lastPasteboardChangeCount != currentChangeCount else {
      return
    }
    lastPasteboardChangeCount = currentChangeCount
    let dragTypes = [NSPasteboard.PasteboardType.URL]
    if dragPasteboard.availableType(from: dragTypes) != nil {
      var isFileTypeSupported = false
      if let urls = dragPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
        urls.forEach { url in
          if url.hasDirectoryPath {
            let filesInFolder = flatten(urls: [url], maxDepth: 1_000)
            if filesInFolder.contains(where: { checkFileType(url: $0) != .notSupported }) {
              isFileTypeSupported = true
            }
          } else {
            let fileType = checkFileType(url: url)
            switch fileType {
            case .image, .gif, .video, .pdf:
              isFileTypeSupported = true
            case .notSupported:
              break
            }
          }
        }
      }
      if isFileTypeSupported {
        show()
      }
    }
  }

  /// Opens files in the main Compresto window without auto-compressing
  func openInApp(inputFileURLs: [URL]) {
    OpenWithHandler.shared.pasteFiles(urls: inputFileURLs)
    DispatchQueue.main.async {
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  func disableDropZone() {
    if let monitor = leftMouseDragMonitor {
      NSEvent.removeMonitor(monitor)
      leftMouseDragMonitor = nil
    }
    cancellables.forEach { $0.cancel() }
    cancellables.removeAll()
  }
}
