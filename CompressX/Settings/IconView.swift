import SwiftUI

struct IconView: View {
  let iconName: String
  let displayName: String
  let twitterHandle: String?
  let selectedIconName: String
  let onTap: () -> Void

  var body: some View {
    HStack {
      if let iconImage = NSImage(named: iconName) {
        Image(nsImage: iconImage)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 64, height: 64, alignment: .center)

        VStack(alignment: .leading) {
          Text(displayName)
            .fontWeight(selectedIconName == iconName ? .bold : .regular)
          if let handle = twitterHandle {
            Link(destination: URL(string: "https://twitter.com/\(handle)")!) {
              Text("@\(handle)")
            }
          }
        }
        Spacer()
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(selectedIconName == iconName ? Color.secondary.opacity(0.15) : Color.white.opacity(0.001))
    )
    .onTapGesture(perform: onTap)
  }
}
