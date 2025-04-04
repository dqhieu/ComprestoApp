  //
  //  DropZoneManager.swift
  //  CompressX
  //
  //  Created by Dinh Quang Hieu on 4/9/24.
  //

import AppKit
import SwiftUI
import Combine

class DropZoneManager: ObservableObject {

  @AppStorage("outputFileNameFormat") var outputFileNameFormat = ""
  @AppStorage("notchStyle") var notchStyle: NotchStyle = .expanded
  @AppStorage("dropZoneEnabled") var dropZoneEnabled = true

  @AppStorage("dropZoneCompressionSettingsType") var dropZoneCompressionSettingsType = DropZoneCompressSettingsType.same

  @AppStorage("dropZoneImageQuality") var dropZoneImageQuality: ImageQuality = .good
  @AppStorage("dropZoneImageFormat") var dropZoneImageFormat: ImageFormat = .same
  @AppStorage("dropZoneImageSize") var dropZoneImageSize: ImageSize = .same
  @AppStorage("dropZoneImageSizeValue") var dropZoneImageSizeValue = 100
  @AppStorage("dropZoneVideoQuality") var dropZoneVideoQuality: VideoQuality = .good
  @AppStorage("dropZoneVideoFormat") var dropZoneVideoFormat: VideoFormat = .same
  @AppStorage("dropZoneVideoDimension") var dropZoneVideoDimension: VideoDimension = .same
  @AppStorage("dropZoneRemoveAudio") var dropZoneRemoveAudio: Bool = true
  @AppStorage("dropZonePreserveTransparency") var dropZonePreserveTransparency: Bool = false
  @AppStorage("dropZoneGifQuality") var dropZoneGifQuality: VideoQuality = .good
  @AppStorage("dropZoneGifDimension") var dropZoneGifDimension: GifDimension = .same
  @AppStorage("dropZoneOutputFolder") var dropZoneOutputFolder: OutputFolder = .same
  @AppStorage("dropZoneCustomOutputFolder") var dropZoneCustomOutputFolder: String = ""
  @AppStorage("dropZoneRemoveFileAfterCompression") var dropZoneRemoveFileAfterCompression: Bool = false
  @AppStorage("dropZonePdfQuality") var dropZonePdfQuality: PDFQuality = .balance
  @AppStorage("dropZoneNestedFolderName") var dropZoneNestedFolderName = "compressed"

  @AppStorage("imageQuality") var defaultImageQuality: ImageQuality = .highest
  @AppStorage("outputImageFormat") var defaultImageFormat: ImageFormat = .same
  @AppStorage("imageSize") var defaultImageSize: ImageSize = .same
  @AppStorage("imageSizeValue") var defaultImageSizeValue = 100

  @AppStorage("videoQuality") var defaultVideoQuality: VideoQuality = .high
  @AppStorage("outputFormat") var defaultVideoFormat: VideoFormat = .same
  @AppStorage("videoDimension") var defaultVideoDimension: VideoDimension = .same
  @AppStorage("removeAudio") var defaultRemoveAudio = false
  @AppStorage("gifQuality") var defaultGifQuality: VideoQuality = .high
  @AppStorage("gifDimension") var defaultGifDimension: GifDimension = .same
  @AppStorage("pdfQuality") var defaultPdfQuality: PDFQuality = .balance
  @AppStorage("outputFolder") var defaultOutputFolder: OutputFolder = .same
  @AppStorage("customOutputFolder") var defaultCustomOutputFolder = ""
  @AppStorage("removeFileAfterCompress") var defaultRemoveFileAfterCompress = false
  @AppStorage("nestedFolderName") var defaultNestedFolderName = "compressed"

  var imageQuality: ImageQuality {
    switch dropZoneCompressionSettingsType {
      case .same:
        return defaultImageQuality
      case .custom:
        return dropZoneImageQuality
    }
  }

  var imageFormat: ImageFormat {
    switch dropZoneCompressionSettingsType {
      case .same:
        return defaultImageFormat
      case .custom:
        return dropZoneImageFormat
    }
  }

  var imageSize: ImageSize {
    switch dropZoneCompressionSettingsType {
      case .same:
        return defaultImageSize
      case .custom:
        return dropZoneImageSize
    }
  }

  var imageSizeValue: Int {
    switch dropZoneCompressionSettingsType {
      case .same:
        return defaultImageSizeValue
      case .custom:
        return dropZoneImageSizeValue
    }
  }

  var gifQuality: VideoQuality {
    switch dropZoneCompressionSettingsType {
      case .same:
        return defaultGifQuality
      case .custom:
        return dropZoneGifQuality
    }
  }

  var gifDimension: GifDimension {
    switch dropZoneCompressionSettingsType {
      case .same:
        return defaultGifDimension
      case .custom:
        return dropZoneGifDimension
    }
  }

  var videoQuality: VideoQuality {
    switch dropZoneCompressionSettingsType {
      case .same:
        return defaultVideoQuality
      case .custom:
        return dropZoneVideoQuality
    }
  }

  var videoFormat: VideoFormat {
    switch dropZoneCompressionSettingsType {
      case .same:
        return defaultVideoFormat
      case .custom:
        return dropZoneVideoFormat
    }
  }

  var videoDimension: VideoDimension {
    switch dropZoneCompressionSettingsType {
      case .same:
        return defaultVideoDimension
      case .custom:
        return dropZoneVideoDimension
    }
  }

  var removeAudio: Bool {
    switch dropZoneCompressionSettingsType {
      case .same:
        return defaultRemoveAudio
      case .custom:
        return dropZoneRemoveAudio
    }
  }

  var outputFolder: OutputFolder {
    switch dropZoneCompressionSettingsType {
      case .same:
        return defaultOutputFolder
      case .custom:
        return dropZoneOutputFolder
    }
  }

  var customOutputFolder: String {
    switch dropZoneCompressionSettingsType {
      case .same:
        return defaultCustomOutputFolder
      case .custom:
        return dropZoneCustomOutputFolder
    }
  }

  var nestedFolderName: String {
    switch dropZoneCompressionSettingsType {
    case .same:
      return defaultNestedFolderName
    case .custom:
      return dropZoneNestedFolderName
    }
  }

  var removeFileAfterCompression: Bool {
    switch dropZoneCompressionSettingsType {
      case .same:
        return defaultRemoveFileAfterCompress
      case .custom:
        return dropZoneRemoveFileAfterCompression
    }
  }

  var pdfQuality: PDFQuality {
    switch dropZoneCompressionSettingsType {
      case .same:
        return defaultPdfQuality
      case .custom:
        return dropZonePdfQuality
    }
  }

  var leftMouseDragMonitor: Any?
  var lastPasteboardChangeCount: Int = NSPasteboard(name: .drag).changeCount

  static let shared = DropZoneManager()

  static let WIDTH: CGFloat = 260

  static var HEIGHT: CGFloat {
    if hasNotch {
      return 70
    }
    return 50
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

    for inputFileURL in inputFileURLs {
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
            return .pdfCompress(pdfQuality: pdfQuality)
          case .video:
            return .video(
              videoQuality: videoQuality,
              videoDimension: videoDimension,
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
          guard LicenseManager.shared.isValid else {
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

    if let monitor = leftMouseDragMonitor {
      NSEvent.removeMonitor(monitor)
    }
    leftMouseDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
      self?.checkForDraggedItems()
      withAnimation {
        self?.calculateOffset()
      }
    }
  }

  let offsetXMax: CGFloat = 20
  let offsetYMax: CGFloat = 10
  @Published var offsetX: CGFloat = 0
  @Published var offsetY: CGFloat = 0

  private func calculateOffset() {
    let mouseLocation = NSEvent.mouseLocation
    let centerPoint = notchTopCenterPoint
    let midY = (NSScreen.main?.frame.height ?? 0) / 2 + (NSScreen.main?.frame.origin.y ?? 0)
    offsetX = offsetXMax * ((mouseLocation.x - centerPoint.x) / centerPoint.x)
    offsetY = offsetYMax * ((mouseLocation.y - midY) / midY)
    let notchDropZoneFrame = NSRect(
      x: notchFrame.origin.x - 150,
      y: notchFrame.origin.y + (NSApplication.shared.mainMenu?.menuBarHeight ?? 0) - 200 + notchFrame.height,
      width: 300 + notchFrame.width,
      height: 200
    )

    if notchDropZoneFrame.contains(mouseLocation) {
      model.show()
    } else {
      model.hide()
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
          let fileType = checkFileType(url: url)
          switch fileType {
          case .image:
            isFileTypeSupported = true
          case .gif:
            isFileTypeSupported = true
          case .video:
            isFileTypeSupported = true
          case .pdf:
            isFileTypeSupported = true
          case .notSupported:
            break
          }
        }
      }
      if isFileTypeSupported {
        show()
      }
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
