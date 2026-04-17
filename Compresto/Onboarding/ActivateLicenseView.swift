//
//  ActivateLicenseView.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 03/02/2024.
//

import SwiftUI
import UniformTypeIdentifiers

struct ActivateLicenseView: View {

  @Binding var currentStep: OnboardingStep

  @Environment(\.colorScheme) var colorScheme
  @ObservedObject var licenseManager = LicenseManager.shared
  @State var licenseKey = ""

  var body: some View {
    VStack {
      Spacer()
      #if SETAPP
      Image("SetappIcon")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 80, height: 80)
      Text("License is managed by Setapp")
        .padding()
      Button {
        withAnimation(.spring(duration: 1)) {
          currentStep = .done
        }
      } label: {
        Text("Next")
      }
      .buttonStyle(NiceButtonStyle())
      #else
      if licenseManager.isValid {
        Text("You have activated your license 🥳")
          .padding()
        Button {
          withAnimation(.spring(duration: 1)) {
            currentStep = .done
          }
        } label: {
          Text("Next")
        }
        .buttonStyle(NiceButtonStyle())
      } else {
        Text("Enter your license key to continue")
          .padding()
        HStack {
          TextField("", text: $licenseKey, prompt: Text("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX").fontDesign(.monospaced))
            .textFieldStyle(.roundedBorder)
            .fontDesign(.monospaced)
            .multilineTextAlignment(.center)
            .labelsHidden()
            .disabled(licenseManager.isActivating)
            .onAppear(perform: {
              licenseKey = licenseManager.licenseKey
            })
            .frame(width: 400)
            .onChange(of: licenseKey, perform: { newValue in
              licenseKey = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            })
          Button {
            Task {
              _ = await licenseManager.activate(key: licenseKey)
            }
          } label: {
            if licenseManager.isActivating {
              ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
            } else {
              Text("Activate")
                .frame(maxWidth: .infinity)
            }
          }
          .buttonStyle(NiceButtonStyle())
          .disabled(licenseManager.isActivating || licenseKey.isEmpty)
          .frame(width: 100)
        }
        if !licenseManager.activateError.isEmpty {
          Text(licenseManager.activateError)
            .foregroundStyle(redColor)
        }
        Spacer()
        Link(destination: URL(string: "https://compresto.app/pricing")!, label: {
          Text("Purchase a license")
        })
        .buttonStyle(NiceButtonStyle())
        Spacer()
      }
      #endif
      Spacer()
    }
  }

  var redColor: Color {
    switch colorScheme {
    case .dark:
      return .red
    case .light:
      return Color(hex: "#b00000")
    @unknown default:
      return .red
    }
  }
}

#Preview {
  ActivateLicenseView(currentStep: .constant(.license))
}
