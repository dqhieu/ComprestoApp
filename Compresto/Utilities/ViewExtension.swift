//
//  ViewExtension.swift
//  Compresto
//
//  Created by Hieu Dinh on 7/1/25.
//

import SwiftUI

extension View {
  func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V { block(self) }

  func pill(colorScheme: ColorScheme, clear: Bool = true) -> some View {
    if #available(macOS 26, *) {
      return AnyView(self.glassEffect(.regular, in: .capsule))
    } else {
      return AnyView(
        self
          .background(clear ? .ultraThinMaterial : .thinMaterial)
          .clipShape(.capsule)
          .overlay(
            Capsule()
              .strokeBorder(
                colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.1),
                lineWidth: 1
              )
          )
      )
    }
  }

  func glassPanel() -> some View {
    if #available(macOS 26, *) {
      return self.glassEffect(.regular, in: .rect(cornerRadius: 16, style: .continuous))
    } else {
      return self
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 16, style: .continuous))
        .overlay(content: {
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        })
        .shadow(radius: 32)
    }
  }

  func onboardingBottomBackground() -> some View {
    if #available(macOS 26, *) {
      return self
        .glassEffect(.regular, in: .rect(corners: .concentric(), isUniform: true))
        .clipShape(.rect(corners: .concentric(), isUniform: true))
        .padding(8)
    } else {
      return self.background(.thickMaterial)
    }
  }

  func glassButton() -> some View {
    if #available(macOS 26, *) {
      return self
        .buttonStyle(.glassProminent)
        .tint(.blue)
        .frame(height: 48)
        .clipShape(.capsule)
    } else {
      return self
        .buttonStyle(NiceButtonStyle())
        .frame(height: 40)
    }
  }

  func glassCard() -> some View {
    if #available(macOS 26, *) {
      return self.glassEffect(in: .rect(cornerRadius: 16, style: .continuous))
    } else {
      return self
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
        )
    }
  }
}
