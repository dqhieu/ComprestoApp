//
//  NotchView.swift
//  Compresto
//
//  Created by Hieu Dinh on 10/5/25.
//

import SwiftUI

struct CornerShape: Shape {
  func path(in rect: CGRect) -> Path {
    Path { path in
      path.move(to: .zero)
      path.addCurve(
        to: CGPoint(x: 12, y: 12),
        control1: CGPoint(x: 12, y: 0),
        control2: CGPoint(x: 12, y: 12))
      path.addLine(to: CGPoint(x: 12, y: 0))

      path.addLine(to: .zero)
      path.closeSubpath()
    }
  }
}

let NOTCH_OFFSET: CGFloat = 47.5

struct NotchView: View {

  @ObservedObject var jobManager = HUDJobManager.shared

  @State private var scale = 0.5
  @State private var offset = NOTCH_OFFSET
  @State private var alpha = 1.0
  @State private var blur = 20.0
  @State private var isMinimized = false
  @State private var workItem: DispatchWorkItem?
  @State private var autoDismissWorkItem: DispatchWorkItem?

  var hasNotch: Bool
  var folderPath: String
  var onClose: () -> Void
  var notchStyle: NotchStyle
  var dismissDelay: TimeInterval?

  var compactHeight: CGFloat {
    if #available(macOS 26, *), let size = notchSize {
      return size.height
    }
    return 32
  }

  var expandedHeight: CGFloat {
    if #available(macOS 26, *) {
      return 100
    }
    return 87
  }

  var progressCount: String {
    let current = jobManager.currentIndex ?? jobManager.jobs.count
    let total = jobManager.jobs.count
    return "\(current)/\(total)"
  }

  var bottomText: String {
    if jobManager.isRunning {
      return jobManager.currentJob?.inputFileURL.lastPathComponent ?? ""
    } else {
      #if !SETAPP
      if jobManager.jobs.contains(where: { $0.isAIRenaming }) {
        return "AI renaming..."
      }
      #endif
      if jobManager.jobs.count > 1 {
        return "Saved to \(folderPath)"
      }
      return "Saved as " + (jobManager.jobs.last?.outputFileURL.lastPathComponent ?? "")
    }
  }

  var bottomRightText: String? {
    if jobManager.isRunning {
      return fileSizeString(from: jobManager.currentJob?.inputFileSize)
    } else {
      if jobManager.jobs.count > 1 {
        return nil
      }
      return fileSizeString(from: jobManager.jobs.last?.outputFileSize)
    }
  }

  var body: some View {
    VStack {
      HStack(spacing: 0) {
        Spacer(minLength: 0)
          .background(.clear)
        CornerShape()
          .fill(Color.black)
          .frame(width: 12, height: notchStyle == .compact || isMinimized ? compactHeight : expandedHeight)
        VStack {
          Spacer(minLength: 0)
          HStack(spacing: 0) {
            Text(progressCount)
            if !(isMinimized || notchStyle == .compact) {
              Text(jobManager.jobs.count > 1 ? " files" : " file")
                .transition(.asymmetric(insertion: .push(from: .trailing), removal: .push(from: .leading)))
            }
            Spacer()
            if jobManager.isRunning {
              Text("\(Int(jobManager.currentProgress * 100))%")
            } else {
              #if !SETAPP
              if jobManager.isAnyJobAIRenaming {
                Image(systemName: "sparkles")
                  .foregroundStyle(.purple)
                  .modifier(AIRenamingSymbolEffect())
                  .scaledToFit()
                  .frame(width: 14, height: 14)
              } else {
                Image(systemName: "checkmark.seal.fill")
                  .foregroundStyle(.green)
                  .scaledToFit()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: 14, height: 14, alignment: .center)
              }
              #else
              Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .scaledToFit()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14, alignment: .center)
              #endif
            }
          }
          .foregroundStyle(.white)
          .opacity(alpha)
          .blur(radius: blur)
          .onTapGesture {
            withAnimation(.spring()) {
              isMinimized = false
            }
          }
          if !(isMinimized || notchStyle == .compact) {
            VStack {
              VStack {
                Spacer(minLength: 0)
                HStack(alignment: .center) {
                  if (jobManager.currentJob?.isProgressNotAvailable ?? false) || (jobManager.currentJob?.isPdf ?? false) {
                    ProgressView()
                      .progressViewStyle(.linear)
                      .preferredColorScheme(.dark)
                  } else {
                    ProgressBar(progress: jobManager.currentProgress)
                  }

                  if jobManager.isRunning {
                    Button(action: {
                      dismiss()
                      jobManager.terminate()
                    }, label: {
                      Image(systemName: "xmark.circle.fill")
                    })
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                  }
                }
                Spacer(minLength: 0)
              }
              .opacity(alpha)
              .blur(radius: blur)
              .frame(height: 15)
              .animation(.spring(), value: jobManager.isRunning)
              .transition(.asymmetric(insertion: .push(from: .top).combined(with: .opacity), removal: .push(from: .bottom).combined(with: .opacity)))
              HStack {
                if jobManager.isRunning {
                  Button(action: {
                    withAnimation(.spring()) {
                      isMinimized = true
                    }
                  }, label: {
                    Image(systemName: "chevron.up")
                  })
                  .buttonStyle(.plain)
                  .foregroundStyle(.white)
                  .transition(.asymmetric(insertion: .push(from: .leading), removal: .push(from: .trailing)))
                }
                Text(bottomText)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .foregroundStyle(.gray)
                  .lineLimit(1)
                  .truncationMode(.middle)
                  .opacity(alpha)
                  .onTapGesture {
                    if !jobManager.isRunning {
                      NSWorkspace.shared.activateFileViewerSelecting(jobManager.jobs.map { $0.outputFileURL} )
                      dismiss()
                    }
                  }
                if let text = bottomRightText {
                  Text(text)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
                    .opacity(alpha)
                }
              }
            }
            .blur(radius: blur)
            .transition(.asymmetric(insertion: .push(from: .top).combined(with: .opacity), removal: .push(from: .bottom).combined(with: .opacity)))
          }
        }
        .padding(.top, 8)
        .padding(.horizontal, notchStyle == .compact || isMinimized ? 8 : 16)
        .padding(.bottom, notchStyle == .compact || isMinimized ? 8 : 16)
        .background(
          UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: notchStyle == .compact || isMinimized ? 8 : 16,
            bottomTrailingRadius: notchStyle == .compact || isMinimized ? 8 : 16,
            topTrailingRadius: 0,
            style: .continuous
          )
          .fill(Color.black)
        )
        .frame(
          width: NotchKit.WIDTH - 12*2 - (notchStyle == .compact || isMinimized ? 32 : 0),
          height: notchStyle == .compact || isMinimized ? compactHeight : expandedHeight
        )
        CornerShape()
          .fill(Color.black)
          .frame(width: 12, height: notchStyle == .compact || isMinimized ? compactHeight : expandedHeight)
          .rotation3DEffect(
            .degrees(180),
            axis: (x: 0.0, y: 1.0, z: 0.0)
          )
        Spacer(minLength: 0)
          .background(.clear)
      }
      Spacer(minLength: 0)
        .background(.clear)
    }
    .scaleEffect(scale)
    .offset(x: 0, y: -offset)
    .task {
      appear()
      if let delay = dismissDelay {
        autoDismissWorkItem = DispatchWorkItem {
          dismiss()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: autoDismissWorkItem!)
      }
    }
    .onChange(of: jobManager.isRunning) { newValue in
      if newValue == false {
        scheduleDismissIfReady()
      } else {
        workItem?.cancel()
        workItem = nil
      }
    }
    #if !SETAPP
    .onChange(of: jobManager.isAnyJobAIRenaming) { isRenaming in
      if !isRenaming && !jobManager.isRunning {
        scheduleDismissIfReady()
      } else if isRenaming {
        workItem?.cancel()
        workItem = nil
      }
    }
    #endif
  }

  func appear() {
    withAnimation(.spring()) {
      scale = 1.0
      offset = 0
    }
    withAnimation(.spring().delay(0.1)) {
      alpha = 1.0
      blur = 0.0
    }
  }

  func scheduleDismissIfReady() {
    guard !jobManager.isRunning else { return }
    #if !SETAPP
    guard !jobManager.isAnyJobAIRenaming else { return }
    #endif
    workItem?.cancel()
    workItem = DispatchWorkItem { dismiss() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem!)
  }

  func dismiss() {
    autoDismissWorkItem?.cancel()
    withAnimation(.spring()) {
      if hasNotch {
        scale = 0.5
        offset = NOTCH_OFFSET
      } else {
        scale = 0.1
        offset = NOTCH_OFFSET * 2
      }
      alpha = 0.0
      blur = 20.0
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      onClose()
    }
  }
}

struct ProgressBar: View {
  /// Progress value between 0.0 and 1.0
  var progress: Double
  var height: CGFloat = 8

  private var clampedProgress: Double {
    min(max(progress, 0), 1)
  }

  var body: some View {
    GeometryReader { proxy in
      let fillWidth = proxy.size.width * clampedProgress

      VStack {
        Spacer(minLength: 0)
        ZStack(alignment: .leading) {
          // Track
          Capsule()
            .fill(.gray.gradient)
            .frame(width: proxy.size.width)
            .opacity(0.7)
            .frame(height: height)

          // Fill
          Capsule()
            .fill(Color.blue.gradient)
            .frame(width: fillWidth)
            .frame(height: height)
        }
        .animation(.default, value: clampedProgress)
        Spacer(minLength: 0)
      }
    }
  }
}
