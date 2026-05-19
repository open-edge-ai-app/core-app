import SwiftUI

struct NativeSessionsIconRow: View {
  var systemImage: String
  var title: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 17, weight: .semibold))
        .foregroundColor(.oeText)
        .frame(width: 26, height: 22)

      Text(title)
        .font(.system(size: 15, weight: .medium))
        .foregroundColor(.oeText)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
  }
}
