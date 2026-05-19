import SwiftUI


struct NativeProjectCreatorSection<Content: View>: View {
  var title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.oeSecondaryText)

      content
    }
  }
}

struct NativeProjectIconOption: View {
  var icon: NativeProjectIcon
  var isSelected: Bool
  var accentColor: NativeAccentColor
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: icon.systemImage)
          .font(.system(size: 19, weight: .semibold))
        Text(icon.title)
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
      }
      .foregroundColor(isSelected ? accentColor.foregroundColor : .oeText)
      .frame(maxWidth: .infinity)
      .frame(height: 78)
      .background(isSelected ? accentColor.color : Color.oeSubtleFill)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(isSelected ? accentColor.color : Color.oeBorder, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }
}
