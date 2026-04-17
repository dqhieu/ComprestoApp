//
//  DropZoneView.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 4/9/24.
//

import SwiftUI
import Combine

class DropZoneViewModel: ObservableObject {
  @Published var scale = 0.0
  @Published var offset = DropZoneManager.HEIGHT
  @Published var alpha = 0.0
  @Published var blur = 20.0
  @Published var isShowing = false


  func show() {
    isShowing = true
    withAnimation(.spring()) {
      scale = 1.0
      offset = 0
    }
    withAnimation(.spring().delay(0.1)) {
      alpha = 1.0
      blur = 0.0
    }
  }

  func hide() {
    isShowing = false
    withAnimation(.spring()) {
      if hasNotch {
        scale = 0.5
        offset = DropZoneManager.HEIGHT
      } else {
        scale = 0.01
        offset = DropZoneManager.HEIGHT
      }
      alpha = 0.0
      blur = 20
    }
  }
}

struct DropZoneView: View {

  @ObservedObject var model: DropZoneViewModel

  var onClose: () -> Void

  @ObservedObject var dropZoneManager = DropZoneManager.shared

  @State var leftMouseReleaseMonitor: Any?

  private var isSplitMode: Bool {
    dropZoneManager.dropZoneMode == .compressAndOpen
  }

  var body: some View {
    VStack {
      HStack(spacing: 0) {
        Spacer(minLength: 0)
          .background(.clear)
        CornerShape()
          .fill(Color.black)
          .frame(width: 12, height: DropZoneManager.HEIGHT)
        VStack {
          if hasNotch {
            Spacer(minLength: notchSize?.height ?? 0)
              .background(.black)
          } else {
            Spacer(minLength: 0)
              .background(.black)
          }
          if isSplitMode {
            splitContent
          } else {
            singleContent
          }
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(
          UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 16,
            bottomTrailingRadius: 16,
            topTrailingRadius: 0,
            style: .continuous
          )
          .fill(Color.black)
        )
        .frame(width: DropZoneManager.WIDTH - 24)
        CornerShape()
          .fill(Color.black)
          .frame(width: 12, height: DropZoneManager.HEIGHT)
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
    .scaleEffect(model.scale)
    .offset(x: 0, y: -model.offset)
    .dropDestination(for: URL.self) { items, location in
      return onDropFiles(items: items, location: location)
    }
    .task {
      leftMouseReleaseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { _ in
        dismiss()
      }
    }
  }

  // MARK: - Single mode content (original)

  private var singleContent: some View {
    HStack {
      Spacer(minLength: 0)
      Text("Drop files here to compress")
        .foregroundStyle(.white)
        .lineLimit(1)
        .offset(x: dropZoneManager.offsetX, y: -dropZoneManager.offsetY)
        .opacity(model.alpha)
        .blur(radius: model.blur)
      Spacer(minLength: 0)
    }
    .background(.black)
  }

  // MARK: - Split mode content

  private var splitContent: some View {
    HStack(spacing: 8) {
      dropZoneHalf(label: "Compress", side: .compress)
      dropZoneHalf(label: "Open in App", side: .open)
    }
    .opacity(model.alpha)
    .blur(radius: model.blur)
    .background(.black)
  }

  private func dropZoneHalf(label: String, side: DropZoneSide) -> some View {
    let isHovered = dropZoneManager.hoveredSide == side
    return Text(label)
      .font(.caption)
      .foregroundStyle(.white)
      .lineLimit(1)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(
            style: StrokeStyle(
              lineWidth: isHovered ? 2 : 1,
              dash: [5, 3]
            )
          )
          .foregroundStyle(isHovered ? .white : .gray)
      )
      .animation(.easeInOut(duration: 0.15), value: isHovered)
  }

  // MARK: - Drop handling

  func onDropFiles(items: [URL], location: CGPoint) -> Bool {
    if isSplitMode {
      // Content area width (excluding corners)
      let contentWidth = DropZoneManager.WIDTH - 24
      // location.x is relative to the drop destination view
      let isRightSide = location.x > contentWidth / 2
      if isRightSide {
        DropZoneManager.shared.openInApp(inputFileURLs: items)
      } else {
        DropZoneManager.shared.queueJob(inputFileURLs: items)
      }
    } else {
      DropZoneManager.shared.queueJob(inputFileURLs: items)
    }
    return true
  }

  func dismiss() {
    if let monitor = leftMouseReleaseMonitor {
      NSEvent.removeMonitor(monitor)
      leftMouseReleaseMonitor = nil
    }
    model.hide()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      onClose()
    }
  }
}
