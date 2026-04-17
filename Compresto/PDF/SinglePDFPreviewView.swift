//
//  SinglePDFPreviewView.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 2/17/25.
//

import SwiftUI

struct SinglePDFPreviewView: View {
  @Environment(\.colorScheme) var colorScheme

  let file: InputFile

  @State var isHovering = false
  @State var id = UUID()

  var body: some View {
    ZStack {
      PDFKitView(url: file.url)
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
          Spacer()
        }
      }
      .padding(8)
    }
    .onHover(perform: { hover in
      isHovering = hover
    })
    .onChange(of: file) { newValue in
      id = UUID()
    }
  }
}

