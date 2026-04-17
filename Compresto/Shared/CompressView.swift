//
//  CompressView.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 21/11/2023.
//

import SwiftUI
import AVFoundation
import AVKit
import TelemetryClient
import UniformTypeIdentifiers
import SwiftDate
import UserNotifications
import SettingsAccess

struct CompressView: View {

  @Environment(\.openWindow) var openWindow

  @AppStorage("pinMainWindowOnTop") var pinMainWindowOnTop = false
  @AppStorage("customOutputFolder") var customOutputFolder = ""
  @AppStorage("removeFileAfterCompress") var removeFileAfterCompress = false
  @AppStorage("sleepWhenFinish") var sleepWhenFinish = false
  @AppStorage("shouldRemindAutoCompress") var shouldRemindAutoCompress = true
  @AppStorage("nestedFolderName") var nestedFolderName = "compressed"
  @AppStorage("videoQuality") var videoQuality: VideoQuality = .high
  @AppStorage("imageQuality") var imageQuality: ImageQuality = .highest
  @AppStorage("gifQuality") var gifQuality: VideoQuality = .high
  @AppStorage("outputFormat") var outputFormat: VideoFormat = .same
  @AppStorage("outputFolder") var outputFolder: OutputFolder = .same
  @AppStorage("outputImageFormat") var outputImageFormat: ImageFormat = .same
  @AppStorage("gifDimension") var gifDimension: GifDimension = .same
  @AppStorage("videoGifDimension") var videoGifDimension: GifDimension = .same
  @AppStorage("videoGifQuality") var videoGifQuality: VideoQuality = .high
  @AppStorage("didOpenProductHuntLink") var didOpenProductHuntLink = false
  @AppStorage("onDropBehavior") var onDropBehavior: OnDropBehavior = .replace
  @AppStorage("imageSize") var imageSize: ImageSize = .same
  @AppStorage("videoDimension") var videoDimension: VideoDimension = .same
  @AppStorage("videoDimensionValue") var videoDimensionValue: Int = 1920
  @AppStorage("removeAudio") var removeAudio = false
  @AppStorage("pdfQuality") var pdfQuality: PDFQuality = .balance
  @AppStorage("ghostscriptPath") var ghostscriptPath = ""
  @AppStorage("subfolderProcessing") var subfolderProcessing: SubfolderProcessing = .none
  @AppStorage("subfolderProcessingLimit") var subfolderProcessingLimit = 1

  @ObservedObject var jobManager = JobManager.shared
  @ObservedObject var licenseManager = LicenseManager.shared
  @ObservedObject var presetManager = PresetManager.shared

  @State var lastWindowRect: NSRect?

  @State var errorMessage: String?
  @State var timeTaken: String?
  @State var hasAudio: Bool = false

  @State var reducedSizeString: String?
  @State var startDate = Date()
  @State var removeFileError: String?
  @State var isInputWebM = false
  @State var showPreserveTransparency = false
  @State var shouldPreserveTransparency = false
  @State var hasImageInput = false
  @State var hasVideoInput = false
  @State var hasGifInput = false
  @State var hasPDFInput = false
  @State var fpsValue: Double = 30
  @State var shouldShowProductHuntLink = false
  @State var isHovering = false
  @State var inputFiles: [InputFile] = []
  @State var startTimes: [URL: CMTime] = [:]
  @State var endTimes: [URL: CMTime] = [:]
  @State var subfolderProcessingLimitText = "1"
  @State var nestedFolderNameText = ""
  @State var targetFileSize: Double = 2048
  @State var checkingAudioTrack = false

  @State var settingRotation: Double = 0
  @State var feedbackBoardAnimationTrigger = 0

  @State var inputPaths: [URL] = []

  @State var filterImages = true
  @State var filterVideos = true
  @State var filterGifs = true
  @State var filterPDFs = true
  @State var showFileTypesPopover = false
  @State var imageCount = 0
  @State var videoCount = 0
  @State var gifCount = 0
  @State var pdfCount = 0
  @State var allValidatedFiles: [URL] = []

  var hasMixedFileTypes: Bool {
    [imageCount > 0, videoCount > 0, gifCount > 0, pdfCount > 0].filter { $0 }.count >= 2
  }

  var activeFilterCount: Int {
    [
      filterImages && imageCount > 0,
      filterVideos && videoCount > 0,
      filterGifs && gifCount > 0,
      filterPDFs && pdfCount > 0
    ].filter { $0 }.count
  }

  var fileTypesButtonLabel: String {
    let total = [imageCount > 0, videoCount > 0, gifCount > 0, pdfCount > 0]
      .filter { $0 }.count
    if activeFilterCount == total { return "All" }
    var parts: [String] = []
    if filterImages && imageCount > 0 { parts.append("Images") }
    if filterVideos && videoCount > 0 { parts.append("Videos") }
    if filterGifs && gifCount > 0 { parts.append("GIFs") }
    if filterPDFs && pdfCount > 0 { parts.append("PDFs") }
    return parts.isEmpty ? "None" : parts.joined(separator: ", ")
  }

  var videoQualities: [VideoQuality] {
    if showPreserveTransparency && shouldPreserveTransparency && outputFormat != .webm {
      return [.highest, .ultraHD, .fullHD]
    }
    return [.highest, .high, .good, .medium, .acceptable, .fileSize]
  }

  var gifQualities: [VideoQuality] = [.highest, .high, .good, .medium, .acceptable]

  var isAllImageInputPNG: Bool {
    let imageInputs = inputFiles.filter { $0.fileType.isImage }
    guard !imageInputs.isEmpty else { return false }
    return imageInputs.allSatisfy { $0.fileType == .image(.png) }
  }

  var body: some View {
    ZStack {
      VStack {
        VStack {
          HStack {
            Spacer()
            Text("Compresto")
              .fontWeight(.bold)
              .foregroundStyle(
                LinearGradient(
                  colors: [Color.primary.opacity(0.7), Color.primary],
                  startPoint: .top,
                  endPoint: .bottom
                )
              )
              .offset(y: 2)
            Spacer()
          }
        }
        .offset(y: -2)
        Spacer()
      }
      .offset(y: -4)
      .zIndex(100)
      .onTapGesture(count: 2) {
        if let keyWindow = NSApplication.shared.keyWindow, let screen = getScreenWithMouse() {
          if keyWindow.frame.size == screen.visibleFrame.size, let rect = lastWindowRect {
            keyWindow.setFrame(rect, display: true, animate: true)
          } else  {
            lastWindowRect = keyWindow.frame
            keyWindow.setFrame(screen.visibleFrame, display: true, animate: true)
          }
        }
      }
      VStack {
        VStack {
          HStack {
            Spacer()
            Button {
              pinMainWindowOnTop.toggle()
            } label: {
              if #available(macOS 15.0, *) {
                Image(systemName: pinMainWindowOnTop ? "pin.square.fill" : "pin.square")
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: 16, height: 16)
                  .symbolRenderingMode(.hierarchical)
                  .contentTransition(.symbolEffect(.replace))
                  .symbolEffect(.wiggle, value: pinMainWindowOnTop)
                  .foregroundStyle(.secondary)
                  .help("Pin window on top: \(pinMainWindowOnTop ? "On" : "Off")")
              } else
              if #available(macOS 14.0, *) {
                Image(systemName: pinMainWindowOnTop ? "pin.square.fill" : "pin.square")
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: 16, height: 16)
                  .symbolRenderingMode(.hierarchical)
                  .contentTransition(.symbolEffect(.replace))
                  .foregroundStyle(.secondary)
                  .help("Pin window on top: \(pinMainWindowOnTop ? "On" : "Off")")
              } else {
                Image(systemName: pinMainWindowOnTop ? "pin.square.fill" : "pin.square")
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: 16, height: 16)
                  .foregroundStyle(.secondary)
                  .help("Pin window on top: \(pinMainWindowOnTop ? "On" : "Off")")
              }
            }
            .buttonStyle(.plain)
            Button {
              feedbackBoardAnimationTrigger += 1
              openWindow(id: "feedback-board")
            } label: {
              if #available(macOS 14.0, *) {
                Image(systemName: "list.clipboard")
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: 16, height: 16)
                  .scaleEffect(1.2)
                  .offset(y: -1)
                  .symbolRenderingMode(.hierarchical)
                  .symbolEffect(.bounce, value: feedbackBoardAnimationTrigger)
                  .foregroundStyle(.secondary)
                  .help("Feedback Board")
              } else {
                Image(systemName: "list.clipboard")
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: 16, height: 16)
                  .scaleEffect(1.2)
                  .offset(y: -1)
                  .symbolRenderingMode(.hierarchical)
                  .foregroundStyle(.secondary)
                  .help("Feedback Board")
              }
            }
            .buttonStyle(.plain)
            Button {
              if #available(macOS 14, *) {
                withAnimation {
                  settingRotation = 180
                } completion: {
                  settingRotation = 0
                }
              }
              openWindow(id: "settings")
            } label: {
              Image(systemName: "gearshape")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(settingRotation))
                .padding(.trailing, 12)
                .help("Settings")
            }
            .buttonStyle(.plain)
          }
        }
        Spacer()
      }
      .offset(y: -4)
      .zIndex(100)
      HStack(spacing: 0) {
        Group {
          if !inputFiles.isEmpty {
            FileGridView(
              inputFiles: inputFiles,
              startTimes: $startTimes,
              endTimes: $endTimes,
              onRemoveFile: { file in
                if jobManager.isRunning {
                  jobManager.jobs.removeAll(where: { $0.inputFileURL == file.url })
                  jobManager.inputFileURLs.removeAll(where: { $0 == file.url })
                  inputFiles.removeAll(where: { $0.url == file.url })
                } else {
                  var inputFileURLs = jobManager.inputFileURLs
                  inputFileURLs.removeAll(where: { $0 == file.url })
                  setSourceFile(urls: inputFileURLs)
                }
              }
            )
            .offset(x: 10)
          } else {
            HStack {
              Spacer()
              VStack {
                Spacer()
                HStack(spacing: 0) {
                  Image("film")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64, alignment: .center)
//                    .rotationEffect(Angle(degrees: isHovering ? -10 : -7))
                    .scaleEffect(isHovering ? 1.05 : 1)
                  Image("photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64, alignment: .center)
                    .scaleEffect(isHovering ? 1.05 : 1)
                }
                HStack(spacing: 0) {
                  Image("pdf")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64, alignment: .center)
//                    .rotationEffect(Angle(degrees: isHovering ? 10 : 7))
                    .scaleEffect(isHovering ? 1.05 : 1)
                  Image("folder")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64, alignment: .center)
                    .scaleEffect(isHovering ? 1.05 : 1)
                }
                Text("Tap to select videos / images / gifs / pdfs / folders")
                  .padding(.top)
                Text("or")
                Text("drop them here")
                Spacer()
              }
              Spacer()
            }
            .scaleEffect(isHovering ? 1.1 : 1)
            .background(Color.secondary.opacity(0.001))
            .offset(x: 10)
            .clipShape(.rect)
            .onHover(perform: { hovering in
              withAnimation {
                isHovering = hovering
              }
            })
            .onTapGesture {
              openFileSelectionPanel()
            }
          }
        }
        .dropDestination(for: URL.self) { items, location in
          handleOnDropFiles(urls: items)
          return true
        }
        .padding(.top, 24)
        .frame(minWidth: 400, minHeight: 350)
        VStack {
          Form {
            if !jobManager.inputFileURLs.isEmpty {
              Section {
                HStack {
                  if jobManager.inputFileURLs.count == 1 {
                    Text("Input file (1)")
                  } else {
                    Text("Input files (\(jobManager.inputFileURLs.count))")
                  }
                  Spacer()
                  Button {
                    jobManager.inputFileURLs.removeAll()
                    inputFiles.removeAll()
                    jobManager.jobs.removeAll()
                    _ = validateInputFile(urls: [])
                    inputPaths = []
                  } label: {
                    Text("Clear")
                  }
                  .disabled(jobManager.isRunning)
                  Button {
                    openFileSelectionPanel()
                  } label: {
                    Text("Change")
                  }
                  .disabled(jobManager.isRunning)
                }
                if hasSubfolders(urls: inputPaths) {
                  VStack {
                    Picker(selection: $subfolderProcessing) {
                      ForEach(SubfolderProcessing.allCases, id: \.self) { behavior in
                        Text(behavior.displayText).tag(behavior.rawValue)
                      }
                    } label: {
                      Text("Include subfolders")
                    }
                    .onChange(of: subfolderProcessing, perform: { newValue in
                      let maxDepth: Int = {
                        switch newValue {
                        case .all:
                          return 1_000
                        case .none:
                          return 1
                        case .custom:
                          return subfolderProcessingLimit
                        }
                      }()
                      updateInputFiles(maxDepth: maxDepth)
                    })
                    .onChange(of: subfolderProcessingLimit, perform: { newValue in
                      subfolderProcessingLimitText = String(newValue)
                      updateInputFiles(maxDepth: newValue)
                    })
                    if subfolderProcessing == .custom {
                      HStack {
                        Text("Max depth")
                          .font(.caption)
                          .foregroundStyle(.secondary)
                        Spacer()
                        TextField("", text: $subfolderProcessingLimitText)
                          .frame(width: 50)
                          .textFieldStyle(.squareBorder)
                          .labelsHidden()
                          .multilineTextAlignment(.trailing)
                          .onSubmit(onMaxDepthSubmittion)
                        Button {
                          onMaxDepthSubmittion()
                        } label: {
                          Text("Update")
                        }
                        .disabled(Int(subfolderProcessingLimitText) == subfolderProcessingLimit)
                      }
                      .task {
                        subfolderProcessingLimitText = String(subfolderProcessingLimit)
                      }
                    }
                  }
                }
                if hasMixedFileTypes {
                  HStack {
                    Text("File types")
                    Spacer()
                    Button {
                      showFileTypesPopover.toggle()
                    } label: {
                      HStack(spacing: 4) {
                        Text(fileTypesButtonLabel)
                        Image(systemName: "chevron.down")
                          .font(.caption2)
                      }
                    }
                    .buttonStyle(.bordered)
                    .popover(isPresented: $showFileTypesPopover, arrowEdge: .bottom) {
                      VStack(alignment: .leading, spacing: 6) {
                        if imageCount > 0 {
                          Toggle("Images (\(imageCount))", isOn: $filterImages)
                            .toggleStyle(.checkbox)
                            .disabled(filterImages && activeFilterCount == 1)
                        }
                        if videoCount > 0 {
                          Toggle("Videos (\(videoCount))", isOn: $filterVideos)
                            .toggleStyle(.checkbox)
                            .disabled(filterVideos && activeFilterCount == 1)
                        }
                        if gifCount > 0 {
                          Toggle("GIFs (\(gifCount))", isOn: $filterGifs)
                            .toggleStyle(.checkbox)
                            .disabled(filterGifs && activeFilterCount == 1)
                        }
                        if pdfCount > 0 {
                          Toggle("PDFs (\(pdfCount))", isOn: $filterPDFs)
                            .toggleStyle(.checkbox)
                            .disabled(filterPDFs && activeFilterCount == 1)
                        }
                      }
                      .padding()
                    }
                  }
                  .onChange(of: filterImages) { _ in applyFileTypeFilter() }
                  .onChange(of: filterVideos) { _ in applyFileTypeFilter() }
                  .onChange(of: filterGifs) { _ in applyFileTypeFilter() }
                  .onChange(of: filterPDFs) { _ in applyFileTypeFilter() }
                }
              }

            }
            Section {
              VStack(spacing: 8) {
                Picker("Output folder", selection: $outputFolder) {
                  ForEach(OutputFolder.allCases, id: \.self) { folder in
                    Text(folder.displayText).tag(folder.rawValue)
                  }
                }
                .pickerStyle(.menu)
                .onChange(of: outputFolder, perform: { newValue in
                  if newValue == .custom, customOutputFolder.isEmpty {
                    openFolderSelectionPanel()
                  }
                })
                if outputFolder == .nested {
                  HStack {
                    Text("Folder name")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                    Spacer()
                    TextField("", text: $nestedFolderNameText, prompt: Text("compressed").font(.caption).foregroundColor(.secondary))
                      .textFieldStyle(.squareBorder)
                      .labelsHidden()
                      .multilineTextAlignment(.trailing)
                      .onChange(of: nestedFolderNameText, perform: { newValue in
                        if nestedFolderNameText.isEmpty {
                          nestedFolderName = "compressed"
                        } else {
                          nestedFolderName = nestedFolderNameText
                        }
                      })
                      .task {
                        nestedFolderNameText = nestedFolderName
                      }
                  }
                }
                if outputFolder == .custom, !customOutputFolder.isEmpty {
                  HStack {
                    Text(customOutputFolder.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false), with: "~/"))
                      .textSelection(.enabled)
                    Spacer()
                    Button {
                      openFolderSelectionPanel()
                    } label: {
                      Text("Change")
                    }
                  }
                  .foregroundStyle(.secondary)
                }
              }
              Toggle(jobManager.inputFileURLs.count > 1 ? "Remove input files" : "Remove input file", isOn: $removeFileAfterCompress)
                .toggleStyle(.switch)
              Toggle("Sleep when finish", isOn: $sleepWhenFinish)
                .toggleStyle(.switch)
            }
            .disabled(jobManager.isRunning)
            if !jobManager.inputFileURLs.isEmpty {
              PresetPickerView()
                .disabled(jobManager.isRunning)
            }
            if hasVideoInput {
              VideoOptionsView(
                showPreserveTransparency: $showPreserveTransparency,
                shouldPreserveTransparency: $shouldPreserveTransparency,
                isInputWebM: $isInputWebM,
                fpsValue: $fpsValue,
                hasAudio: $hasAudio,
                targetFileSize: $targetFileSize,
                checkingAudioTrack: $checkingAudioTrack
              )
              
            }
            if hasImageInput {
              ImageOptionsView(isInputPNG: isAllImageInputPNG)

            }
            if hasGifInput {
              GifOptionsView()
                
            }
            if hasPDFInput {
              PdfOptionsView()
                
            }
            if jobManager.jobs.contains(where: { FileManager.default.fileExists(atPath: $0.outputFileURL.path(percentEncoded: false)) }) {
              if jobManager.jobs.count == 1, !jobManager.isRunning {
                OutputView(
                  reducedSizeString: reducedSizeString,
                  timeTaken: timeTaken
                )
              } else if (jobManager.isRunning && (jobManager.currentIndex ?? 0) > 1) || !jobManager.isRunning {
                OutputView(
                  reducedSizeString: reducedSizeString,
                  timeTaken: timeTaken
                )
              }
            }
            if let message = errorMessage {
              Section {
                Text("\(Image(systemName: "xmark.diamond.fill")) \(message)")
                  .foregroundStyle(.red)
                if message.lowercased().contains("bad cpu type in executable") {
                  Button {
                    NSWorkspace.shared.open(URL(string: "https://compresto.app/docs/troubleshooting/bad-cpu-type-in-executable")!)
                  } label: {
                    Text("Open documentation")
                  }
                }
                if message.lowercased().contains("ghostscript is not installed") {
                  Button {
                    NSWorkspace.shared.open(URL(string: "https://compresto.app/docs/guides/getting-started/install-ghostscript")!)
                  } label: {
                    Text("Setup PDF compression")
                  }
                }
              }
            }
            if shouldShowProductHuntLink,
               let url = jobManager.jobs.first?.outputFileURL, FileManager.default.fileExists(atPath: url.path(percentEncoded: false)),
               let outputFileSize = url.fileSize,
               let inputFileSize = jobManager.jobs.first?.inputFileSize,
               outputFileSize < inputFileSize {
              Button {
                NSWorkspace.shared.open(URL(string: "https://www.producthunt.com/products/compressx/reviews/new")!)
                didOpenProductHuntLink = true
              } label: {
                Text("💛 Enjoy the app? Please review us on Product Hunt \(Image(systemName: "arrow.up.forward"))")
                  .multilineTextAlignment(.leading)
              }
              .buttonStyle(.link)
              
            }
          }
          .frame(width: 320)
          .scrollIndicators(.hidden)
          .formStyle(.grouped)
          .task {
            OpenWithHandler.shared.onOpenFile { jobs in
              if jobManager.isRunning {
                jobManager.queue(newJobs: jobs)
                setInputFiles(urls: jobManager.inputFileURLs)
              } else {
                jobManager.jobs.removeAll(where: { FileManager.default.fileExists(atPath: $0.outputFileURL.path(percentEncoded: false)) })
                jobManager.queue(newJobs: jobs)
                setInputFiles(urls: jobManager.inputFileURLs)
                compress(jobs: jobs)
              }
            }
            OpenWithHandler.shared.onPasteFiles { urls in
              handleOnDropFiles(urls: urls)
            }
          }
          .onChange(of: imageQuality) { _ in clearPresetIfNotApplying() }
          .onChange(of: outputImageFormat) { _ in clearPresetIfNotApplying() }
          .onChange(of: imageSize) { _ in clearPresetIfNotApplying() }
          .onChange(of: videoQuality) { _ in clearPresetIfNotApplying() }
          .onChange(of: outputFormat) { _ in clearPresetIfNotApplying() }
          .onChange(of: videoDimension) { _ in clearPresetIfNotApplying() }
          .onChange(of: removeAudio) { _ in clearPresetIfNotApplying() }
          .onChange(of: gifQuality) { _ in clearPresetIfNotApplying() }
          .onChange(of: gifDimension) { _ in clearPresetIfNotApplying() }
          .onChange(of: pdfQuality) { _ in clearPresetIfNotApplying() }
          Section {
            if jobManager.isPaused {
              // Paused state - show resume button with remaining file count
              let remainingCount = jobManager.jobs.filter {
                !FileManager.default.fileExists(atPath: $0.outputFileURL.path(percentEncoded: false))
              }.count
              HStack {
                Button {
                  Task {
                    await jobManager.resume()
                  }
                } label: {
                  HStack {
                    Image(systemName: "play.fill")
                    Text("Resume (\(remainingCount) \(remainingCount == 1 ? "file" : "files"))")
                  }
                  .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                Button {
                  jobManager.terminate()
                } label: {
                  Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .help("Cancel all")
              }
              .padding(8)
              .background(.regularMaterial)
              .clipShape(.rect(cornerRadius: 12, style: .continuous))
              .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .stroke(.secondary.opacity(0.3), lineWidth: 1)
              )
            } else if jobManager.isRunning, let job = jobManager.currentJob {
              VStack(alignment: .leading, spacing: 4) {
                HStack {
                  switch job.outputType {
                  case .video:
                    if jobManager.currentJob?.isProgressNotAvailable ?? false || jobManager.currentProgress <= 0.01 {
                      ProgressView {
                        HStack {
                          Text(jobManager.shouldPause ? "Pausing after current file..." : (jobManager.currentJob?.status.nonEmptyString ?? "Compressing"))
                          if !jobManager.shouldPause, jobManager.jobs.count > 1, let index = jobManager.currentIndex {
                            Text("\(index)/\(jobManager.jobs.count) files")
                              .contentTransition(.numericText())
                              .animation(.default, value: jobManager.currentIndex)
                          }
                          Spacer()
                          Text(startDate, style: .relative)
                            .contentTransition(.numericText())
                        }
                      }
                      .progressViewStyle(.linear)
                    } else {
                      ProgressView(value: jobManager.currentProgress, total: 1) {
                        HStack {
                          Text(jobManager.shouldPause ? "Pausing after current file..." : (jobManager.currentJob?.status.nonEmptyString ?? "Compressing"))
                          if !jobManager.shouldPause, jobManager.jobs.count > 1, let index = jobManager.currentIndex {
                            Text("\(index)/\(jobManager.jobs.count) files")
                              .contentTransition(.numericText())
                              .animation(.default, value: jobManager.currentIndex)
                          }
                          Spacer()
                          Text(String(Int(jobManager.currentProgress * 100)) + "%")
                            .contentTransition(.numericText())
                            .animation(.default, value: jobManager.currentProgress)
                        }
                      }
                      .progressViewStyle(.linear)
                    }

                  case .image, .pdfCompress:
                    if jobManager.jobs.count > 1 {
                      ProgressView(value: Double(jobManager.currentIndex ?? 0) - 1, total: max(Double(jobManager.currentIndex ?? 0), Double(jobManager.jobs.count))) {
                        HStack {
                          Text(jobManager.shouldPause ? "Pausing after current file..." : "Compressing")
                          if !jobManager.shouldPause, jobManager.jobs.count > 1, let index = jobManager.currentIndex {
                            Text("\(index)/\(jobManager.jobs.count) files")
                              .contentTransition(.numericText())
                              .animation(.default, value: jobManager.currentIndex)
                          }
                          Spacer()
                          Text("\(jobManager.currentIndexProgress ?? 0)%")
                            .contentTransition(.numericText())
                            .animation(.default, value: jobManager.currentIndexProgress)
                        }
                      }
                      .progressViewStyle(.linear)
                    } else {
                      ProgressView {
                        HStack {
                          Text(jobManager.shouldPause ? "Pausing after current file..." : "Compressing")
                          Spacer()
                          Text(startDate, style: .relative)
                            .contentTransition(.numericText())
                        }
                      }
                      .progressViewStyle(.linear)
                    }
                  case .gif:
                    ProgressView(value: jobManager.currentProgress, total: 1) {
                      HStack {
                        Text(jobManager.shouldPause ? "Pausing after current file..." : "Converting")
                        if !jobManager.shouldPause, jobManager.jobs.count > 1, let index = jobManager.currentIndex {
                          Text("\(index)/\(jobManager.jobs.count) files")
                            .contentTransition(.numericText())
                            .animation(.default, value: jobManager.currentIndex)
                        }
                        Spacer()
                        Text(String(Int(jobManager.currentProgress * 100)) + "%")
                          .contentTransition(.numericText())
                          .animation(.default, value: jobManager.currentProgress)
                      }
                    }
                    .progressViewStyle(.linear)
                  case .gifCompress:
                    ProgressView(value: jobManager.currentProgress, total: 1) {
                      HStack {
                        Text(jobManager.shouldPause ? "Pausing after current file..." : "Compressing")
                        if !jobManager.shouldPause, jobManager.jobs.count > 1, let index = jobManager.currentIndex {
                          Text("\(index)/\(jobManager.jobs.count) files")
                            .contentTransition(.numericText())
                            .animation(.default, value: jobManager.currentIndex)
                        }
                        Spacer()
                        Text(String(Int(jobManager.currentProgress * 100)) + "%")
                          .contentTransition(.numericText())
                          .animation(.default, value: jobManager.currentProgress)
                      }
                    }
                    .progressViewStyle(.linear)
                  }
                  Spacer()
                  HStack(spacing: 8) {
                    if !jobManager.isPaused && !jobManager.shouldPause {
                      Button {
                        jobManager.pause()
                      } label: {
                        Image(systemName: "pause.circle.fill")
                      }
                      .buttonStyle(.borderless)
                      .help("Pause after current file")
                    }
                    Button {
                      jobManager.terminate()
                    } label: {
                      Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Cancel all")
                  }
                }
                if jobManager.jobs.count > 1 {
                  Text(jobManager.currentJob?.inputFileURL.lastPathComponent ?? "")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
              }
              .padding(8)
              .background(.regularMaterial)
              .clipShape(.rect(cornerRadius: 12, style: .continuous))
              .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .stroke(.secondary.opacity(0.3), lineWidth: 1)
              )
            } else {
              Button(action: {
                compress()
              }, label: {
                Text(hasVideoInput && !hasImageInput && outputFormat == .gif ? "Convert" : "Compress")
                  .fontWeight(.bold)
                  .foregroundStyle(.primary)
                  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
              })
              .glassButton()
              .disabled(jobManager.isRunning || jobManager.inputFileURLs.isEmpty)
              .keyboardShortcut(.defaultAction)
            }
          }
          .padding(10)
          .frame(width: 320)
        }
        .glassPanel()
        .background {
          LinearGradient(
            stops: [
              Gradient.Stop(color: Color.blue.opacity(0.2), location: 0),
              Gradient.Stop(color: Color.clear, location: 1)
            ],
            startPoint: .bottomTrailing,
            endPoint: .topLeading
          )
          .clipShape(.rect(cornerRadii: RectangleCornerRadii(topLeading: 16, bottomLeading: 16, bottomTrailing: 16, topTrailing: 16), style: .continuous))
        }
        .padding(.top, 21)
        .padding(.leading, 10)
        .padding(.trailing, 10)
        .padding(.bottom, -10)
      }
    }
    .offset(x: 0, y: -20)
  }

  /// Clears the selected preset when the user manually changes a setting.
  /// We use a flag to avoid clearing during `applyPreset()` which also triggers onChange.
  private func clearPresetIfNotApplying() {
    // Only clear if not currently applying a preset (applyPreset sets the ID before writing values)
    // Since @AppStorage writes are synchronous, the onChange fires inline.
    // We detect this by checking if the current settings still match the selected preset.
    guard !presetManager.selectedPresetId.isEmpty else { return }
    guard let preset = presetManager.preset(for: presetManager.selectedPresetId) else {
      presetManager.selectedPresetId = ""
      return
    }
    let matches = imageQuality == preset.imageQuality
      && outputImageFormat == preset.imageFormat
      && imageSize == preset.imageSize
      && videoQuality == preset.videoQuality
      && outputFormat == preset.videoFormat
      && videoDimension == preset.videoDimension
      && removeAudio == preset.removeAudio
      && gifQuality == preset.gifQuality
      && gifDimension == preset.gifDimension
      && pdfQuality == preset.pdfQuality
    if !matches {
      presetManager.selectedPresetId = ""
    }
  }
}
