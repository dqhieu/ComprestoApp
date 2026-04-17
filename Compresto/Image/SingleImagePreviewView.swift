//
//  SingleImagePreviewView.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 2/17/25.
//

import SwiftUI

struct SingleImagePreviewView: View {
  @Environment(\.colorScheme) var colorScheme

  let file: InputFile
  @State private var image: NSImage?
  @State var isHovering = false
  @State private var dimensionsText: String?

  var body: some View {
    ZStack {
      VStack(spacing: 0) {
        Spacer(minLength: 0)
        HStack(spacing: 0) {
          Spacer(minLength: 0)
          if let loadedImage = image {
            Image(nsImage: loadedImage)
              .resizable()
              .aspectRatio(contentMode: .fit)
          } else {
            ProgressView()
          }
          Spacer(minLength: 0)
        }
        Spacer(minLength: 0)
      }
      VStack {
        HStack {
          Text("\(file.fileExtension) | \(file.fileSize)")
            .padding(6)
            .pill(colorScheme: colorScheme, clear: !isHovering)
          Spacer()
        }
        Spacer()
        HStack {
          Text("\(file.fileName)")
            .lineLimit(1)
            .padding(6)
            .pill(colorScheme: colorScheme, clear: !isHovering)
          if let dimensionsText {
            Text(dimensionsText)
              .padding(6)
              .pill(colorScheme: colorScheme, clear: !isHovering)
          }
          Spacer()
        }
      }
      .padding(8)
    }
    .task {
      loadImage(url: file.url)
    }
    .onHover(perform: { hover in
      isHovering = hover
    })
    .onChange(of: file, perform: { newValue in
      loadImage(url: newValue.url)
    })
  }

  func loadImage(url: URL) {
    Task(priority: .utility) {
      if let nsImage = NSImage(contentsOf: url) {
        await MainActor.run {
          image = nsImage
        }
      }
      if let imageRep = NSImageRep(contentsOf: url) {
        dimensionsText = "\(imageRep.pixelsWide)×\(imageRep.pixelsHigh)"
      }
    }
  }
}
