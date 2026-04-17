//
//  LicenseSettingsV2View.swift
//  Compresto
//
//  Created by Dinh Quang Hieu on 12/21/24.
//

import SwiftUI

struct LicenseSettingsV2View: View {

  @ObservedObject var licenseManager = LicenseManager.shared
  @State var licenseKey = ""

  var body: some View {
    Form {
      #if SETAPP
      Image("SetappIcon")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 80, height: 80)
      Text("License is managed by Setapp")
      #else
      if !licenseManager.licenseKey.isEmpty {
        if let status = licenseManager.licenseStatus {
          VStack(alignment: .leading) {
            HStack(spacing: 0) {
              Text("License status")
              Spacer()
              if licenseManager.isSubscription {
                if licenseManager.licenseStatus == "active" {
                  Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                  Text(" Active")
                } else if licenseManager.licenseStatus == "expired" {
                  Image(systemName: "calendar.badge.exclamationmark").foregroundStyle(.red)
                  Text(" Expired")
                } else {
                  Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                  Text(" \(licenseManager.licenseStatus ?? "Unknown")")
                }
              } else {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text(" Valid")
              }
              if licenseManager.isValidating {
                ProgressView()
                  .controlSize(.small)
                  .padding(.leading, 4)
              } else {
                Button {
                  Task {
                    await licenseManager.validate()
                  }
                } label: {
                  Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
                .foregroundStyle(.secondary)
                .help("Refresh license status")
              }
            }
          }
          if !licenseManager.isSubscription {
            HStack {
              switch status {
              case "active":
                if !licenseManager.expiryDate.isEmpty {
                  Text("Updates available until")
                  Spacer()
                  Text(convertISO8601ToReadableDate(isoDate: licenseManager.expiryDate))
                } else {
                  Text("License expiry")
                  Spacer()
                  Text("Never")
                }
              case "expired":
                Text("You're no longer able to receive new updates")
                Spacer()
                Button {
                  NSWorkspace.shared.open(licenseManager.renewLicenseURL)
                } label: {
                  Text("Renew license")
                }
              default:
                EmptyView()
              }
            }
          }
        }
        if licenseManager.currentProviderType != .polar {
          HStack(spacing: 0) {
            Text("License usage")
            Spacer()
            Text(licenseUsageText)
          }
        }
        HStack(spacing: 0) {
          Text("License key")
          Spacer(minLength: 0)
          Text(licenseManager.licenseKey)
            .textSelection(.enabled)
            .fontDesign(.monospaced)
          Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(licenseManager.licenseKey, forType: .string)
          } label: {
            Image(systemName: "doc.on.doc")
          }
          .buttonStyle(.plain)
          .padding(.leading, 4)
          .foregroundStyle(.secondary)
        }
        if !licenseManager.customerEmail.isEmpty {
          HStack(spacing: 0) {
            Text("Email")
            Spacer(minLength: 0)
            Text(licenseManager.customerEmail)
              .textSelection(.enabled)
            Button {
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(licenseManager.customerEmail, forType: .string)
            } label: {
              Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
            .foregroundStyle(.secondary)
          }
        }
        if !licenseManager.providerDisplayName.isEmpty {
          HStack(spacing: 0) {
            Text("Provider")
            Spacer()
            Text(licenseManager.providerDisplayName)
              .foregroundStyle(.secondary)
          }
        }
        HStack {
          Spacer()
          if licenseManager.currentProviderType == .polar {
            Button {
              NSWorkspace.shared.open(licenseManager.customerPortalURL)
            } label: {
              Text("Customer portal")
            }
          } else {
            if licenseManager.isSubscription {
              Button {
                NSWorkspace.shared.open(licenseManager.billingURL)
              } label: {
                Text("Manage billing")
              }
            }
            Button {
              NSWorkspace.shared.open(licenseManager.manageOrdersURL)
            } label: {
              Text("Manage license")
            }
          }
          Button(action: {
            Task {
              await licenseManager.deactivate()
            }
          }, label: {
            Text("Unlink device")
              .foregroundStyle(.red)
          })
          Spacer()
        }
      } else {
        VStack(alignment: .leading) {
          HStack {
            Text("Enter your license key")
            Spacer()
          }
          HStack {
            TextField("", text: $licenseKey, prompt: Text("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX").fontDesign(.monospaced))
              .fontDesign(.monospaced)
              .textFieldStyle(.squareBorder)
              .labelsHidden()
              .disabled(licenseManager.isActivating)
              .onAppear(perform: {
                licenseKey = licenseManager.licenseKey
              })
              .onChange(of: licenseKey, perform: { newValue in
                licenseKey = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
              })
            Spacer()
            if licenseManager.isActivating {
              ProgressView()
                .controlSize(.small)
            } else {
              Button {
                Task {
                  await licenseManager.activate(key: licenseKey)
                }
              } label: {
                Text("Activate")
              }
              .buttonStyle(.borderedProminent)
              .disabled(shouldDisableActivateButton)
            }
          }
          if !licenseManager.activateError.isEmpty {
            VStack(alignment: .leading) {
              Text(licenseManager.activateError)
                .foregroundStyle(.red)
              if licenseKey.hasPrefix("POLAR") {
                Button {
                  NSWorkspace.shared.open(licenseManager.customerPortalURL)
                } label: {
                  Text("Open Customer Portal")
                }
              } else {
                Button {
                  NSWorkspace.shared.open(licenseManager.manageOrdersURL)
                } label: {
                  Text("Open My Orders page")
                }
              }
            }
          }
        }
      }
      #endif
    }
    .formStyle(.grouped)
    .scrollDisabled(true)
  }

  var licenseUsageText: String {
    if licenseManager.activation_limit == 1 {
      return "\(licenseManager.activation_usage)/\(licenseManager.activation_limit) device activated"
    }
    return "\(licenseManager.activation_usage)/\(licenseManager.activation_limit) devices activated"
  }

  var shouldDisableActivateButton: Bool {
    return licenseManager.isActivating || licenseKey.isEmpty || licenseKey == licenseManager.licenseKey
  }
}
