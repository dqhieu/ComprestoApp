//
//  OutputView.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 1/21/25.
//

import SwiftUI

struct OutputView: View {

  @AppStorage("outputFormat") var outputFormat: VideoFormat = .same

  @ObservedObject var jobManager = JobManager.shared
  @State private var showCopied = false

  let reducedSizeString: String?
  let timeTaken: String?

  var outputFileCount: Int {
    var count = 0
    for job in jobManager.jobs {
      if FileManager.default.fileExists(atPath: job.outputFileURL.path(percentEncoded: false)), (jobManager.isRunning && (jobManager.currentIndex ?? 0) > (jobManager.getJobIndex(job) ?? 0) + 1) || (!jobManager.isRunning) {
        count += 1
      }
    }
    return count
  }

  var body: some View {
    Section {
      HStack {
        if jobManager.jobs.count > 1 {
          Image(systemName: "checkmark.seal.fill")
            .foregroundStyle(.green)
          Text("Output files (\(jobManager.isRunning ? (jobManager.currentIndex ?? 1) - 1 : outputFileCount))")
        } else {
          let reducedSize = (jobManager.jobs.first?.inputFileSize ?? 0) - (jobManager.jobs.first?.outputFileSize ?? 0)
          if reducedSize > 0 {
            Image(systemName: "checkmark.seal.fill")
              .foregroundStyle(.green)
          } else if outputFormat != .gif {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundStyle(.orange)
          }
          Text("Output file")
        }
        Spacer()
        Button {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.writeObjects(jobManager.jobs.map { $0.outputFileURL} as [NSPasteboardWriting])
          showCopied = true
          DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopied = false
          }
        } label: {
          Text(showCopied ? "Copied!" : "Copy")
        }
        Button {
          NSWorkspace.shared.activateFileViewerSelecting(jobManager.jobs.map { $0.outputFileURL} )
        } label: {
          Text("Reveal")
        }
      }
      ScrollView {
        LazyVStack {
          ForEach(jobManager.jobs) { job in
            if FileManager.default.fileExists(atPath: job.outputFileURL.path(percentEncoded: false)), (jobManager.isRunning && (jobManager.currentIndex ?? 0) > (jobManager.getJobIndex(job) ?? 0) + 1) || (!jobManager.isRunning) {
              if job.id.uuidString != jobManager.jobs.first?.id.uuidString {
                Divider()
              }
              Button {
                NSWorkspace.shared.activateFileViewerSelecting([job.outputFileURL])
              } label: {
                VStack(alignment: .leading, spacing: 8) {
                  HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                      HStack(spacing: 4) {
                        if job.aiRenamedName != nil {
                          Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        Text(job.outputFileURL.lastPathComponent)
                      }
                      if job.isAIRenaming {
                        HStack {
                          Image(systemName: "sparkles")
                            .font(.caption2)
                            .modifier(AIRenamingSymbolEffect())
                          Text("AI renaming...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                      } else if let error = job.aiRenamingError {
                        Text(error)
                          .font(.caption)
                          .foregroundStyle(.red)
                      }
                    }
                    Spacer()
                    Text(fileSizeString(from: job.outputFileSize ?? 0))
                  }
                  if jobManager.jobs.count > 1 {
                    HStack(alignment: .top, spacing: 2) {
                      let reducedSize = (job.inputFileSize ?? 0) - (job.outputFileSize ?? 0)
                      if reducedSize > 0 {
                        Text("Reduced")
                          .foregroundStyle(.secondary)
                      } else if outputFormat != .gif {
                        Image(systemName: "exclamationmark.triangle.fill")
                          .foregroundStyle(.orange)
                      }
                      Text(fileSizeString(from: reducedSize))
                        .foregroundStyle(.secondary)
                      if let reducedPercentage = job.reducedPercentage {
                        Text("(\(reducedPercentage))")
                          .foregroundStyle(.secondary)
                      }
                      Spacer()
                      Image(systemName: "arrow.up.forward")
                        .foregroundStyle(.secondary)
                    }
                  }
                }
                .background(Color.white.opacity(0.001))
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
      .frame(maxHeight: 200)
      if let reducedSizeString = reducedSizeString {
        HStack {
          Text(jobManager.jobs.count == 1 ? "Size reduced" : "Total size reduced")
          Spacer()
          Text(reducedSizeString)
          if jobManager.jobs.count == 1, let job = jobManager.jobs.first, let reducedPercentage = job.reducedPercentage {
            Text("(\(reducedPercentage))")
          }
        }
      }
      if outputFormat != .gif,
         jobManager.jobs.contains(where: { ($0.outputFileSize ?? 0) > ($0.inputFileSize ?? 0) }) {
        Text(jobManager.jobs.count == 1
             ? "Input is already well-optimized. Try lower quality or resolution for smaller output."
             : "Some inputs are already well-optimized. Try lower quality or resolution for smaller output.")
          .font(.callout)
          .foregroundStyle(.orange)
      }
      if let timeTaken = timeTaken {
        HStack {
          Text("Time taken")
          Spacer()
          Text(timeTaken)
        }
      }
    }
  }
}

struct AIRenamingSymbolEffect: ViewModifier {
  func body(content: Content) -> some View {
    if #available(macOS 15.0, *) {
      content.symbolEffect(.breathe)
    } else if #available(macOS 14.0, *) {
      content.symbolEffect(.pulse)
    } else {
      content
    }
  }
}
