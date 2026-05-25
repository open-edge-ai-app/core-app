import SwiftUI

struct NativeTodoInlineTagGroup: View {
  var labels: [NativeTodoLabel]

  private var visibleLabels: [NativeTodoLabel] {
    Array(labels.prefix(1))
  }

  var body: some View {
    HStack(spacing: 5) {
      ForEach(visibleLabels) { label in
        NativeTodoInlineTagChip(label: label)
      }

    }
    .fixedSize(horizontal: true, vertical: false)
  }
}

struct NativeTodoInlineTagChip: View {
  var label: NativeTodoLabel

  var body: some View {
    HStack(spacing: 4) {
      Circle()
        .fill(Color(todoLabelHex: label.colorHex))
        .frame(width: 6, height: 6)

      Text(label.title)
        .font(.system(size: 11, weight: .bold))
        .lineLimit(1)
    }
    .foregroundColor(.oeSecondaryText)
    .padding(.horizontal, 7)
    .frame(maxWidth: 72)
    .frame(height: 22)
    .nativeLiquidGlassCapsule()
  }
}

struct NativeTodoTagTaskGroupView<Content: View>: View {
  var title: String
  var colorHex: String?
  @ViewBuilder var content: Content

  private var markerColor: Color {
    guard let colorHex else {
      return .oeMutedText
    }
    return Color(todoLabelHex: colorHex)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Circle()
          .fill(markerColor)
          .frame(width: 9, height: 9)

        Text(title)
          .font(.system(size: 17, weight: .bold))
          .foregroundColor(.oeSecondaryText)
          .lineLimit(1)

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 4)
      .padding(.top, 4)

      VStack(alignment: .leading, spacing: 10) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct NativeTodoEmptyRow: View {
  var title: String

  var body: some View {
    Text(title)
      .font(.system(size: 14, weight: .semibold))
      .foregroundColor(.oeMutedText)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 18)
      .padding(.vertical, 16)
    .nativeLiquidGlass(cornerRadius: 14)
    .nativeGlassStroke(cornerRadius: 14, color: Color.oeBorder.opacity(0.28))
  }
}
