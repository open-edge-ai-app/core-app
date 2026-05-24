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
      .nativeLiquidGlass(
        cornerRadius: 14,
        tint: isSelected ? accentColor.color.opacity(0.88) : nil,
        interactive: true
      )
      .nativeGlassStroke(cornerRadius: 14, color: isSelected ? accentColor.color : Color.oeBorder.opacity(0.34))
    }
    .buttonStyle(.plain)
  }
}
