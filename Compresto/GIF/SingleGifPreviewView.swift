//
//  SingleGifPreviewView.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 2/17/25.
//

import SwiftUI

struct SingleGifPreviewView: View {
  @Environment(\.colorScheme) var colorScheme

  let file: InputFile

  @State var isHovering = false
  @State var id = UUID()
  @State private var dimensionsText: String?

  var body: some View {
    ZStack {
      GIFImage(url: file.url)
        .id(id)
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
    .onHover(perform: { hover in
      isHovering = hover
    })
    .task {
      reloadDimension()
    }
    .onChange(of: file) { newValue in
      id = UUID()
      reloadDimension()
    }
  }

  func reloadDimension() {
    Task {
      if let imageRep = NSImageRep(contentsOf: file.url) {
        dimensionsText = "\(imageRep.pixelsWide)×\(imageRep.pixelsHigh)"
      }
    }
  }
}
