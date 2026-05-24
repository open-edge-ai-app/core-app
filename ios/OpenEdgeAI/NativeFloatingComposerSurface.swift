import SwiftUI

let nativeComposerInputCornerRadius: CGFloat = 30
let nativeComposerInlineControlSize: CGFloat = 40
let nativeComposerSubmitControlSize: CGFloat = 42
let nativeComposerScrollBottomPadding: CGFloat = 134

struct NativeComposerInputSurface<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme

  var isFocused: Bool
  var isDisabled: Bool = false
  var isError: Bool = false
  var accentColor: Color
  @ViewBuilder var content: Content

  var body: some View {
    content
      .disabled(isDisabled)
      .background(glassFill)
      .overlay(glassHighlight)
      .overlay(glassStroke)
      .opacity(isDisabled ? 0.48 : 1)
      .contentShape(RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius, style: .continuous))
  }

  private var glassFill: some View {
    RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius, style: .continuous)
      .fill(.ultraThinMaterial)
      .overlay {
        RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius, style: .continuous)
          .fill(surfaceTint)
      }
  }

  private var surfaceTint: Color {
    if colorScheme == .dark {
      return Color.white.opacity(isFocused ? 0.13 : 0.1)
    }
    return Color.white.opacity(isFocused ? 0.82 : 0.72)
  }

  private var glassHighlight: some View {
    RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius - 1, style: .continuous)
      .inset(by: 1)
      .stroke(
        LinearGradient(
          colors: [
            Color.white.opacity(colorScheme == .dark ? 0.18 : 0.7),
            Color.white.opacity(colorScheme == .dark ? 0.04 : 0.18),
            Color.black.opacity(colorScheme == .dark ? 0.12 : 0.06)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        lineWidth: 0.8
      )
      .allowsHitTesting(false)
  }

  private var glassStroke: some View {
    RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius, style: .continuous)
      .stroke(strokeColor, lineWidth: isFocused || isError ? 1.2 : 1)
      .allowsHitTesting(false)
  }

  private var strokeColor: Color {
    if isError {
      return Color.oeDestructive.opacity(0.5)
    }
    if isFocused {
      return accentColor.opacity(0.42)
    }
    return Color.white.opacity(colorScheme == .dark ? 0.18 : 0.58)
  }
}

struct NativeComposerInlineIcon: View {
  var systemName: String
  var color: Color = .oeText
  var size: CGFloat = 22

  var body: some View {
    Image(systemName: systemName)
      .font(.system(size: size, weight: .medium))
      .foregroundColor(color)
      .frame(width: nativeComposerInlineControlSize, height: nativeComposerInlineControlSize)
      .contentShape(Rectangle())
  }
}

struct NativeComposerCircleSurface<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme

  var isActive: Bool = false
  var accentColor: Color
  @ViewBuilder var content: Content

  var body: some View {
    if #available(iOS 26.0, *) {
      content
        .background(circleMaterial)
        .glassEffect(
          .regular
            .tint(isActive ? accentColor.opacity(0.26) : neutralGlassTint)
            .interactive(),
          in: .circle
        )
        .overlay(circleStroke)
    } else {
      content
        .background(circleMaterial)
        .overlay(circleStroke)
    }
  }

  private var neutralGlassTint: Color {
    colorScheme == .dark
      ? Color.white.opacity(0.08)
      : Color.white.opacity(0.2)
  }

  private var circleMaterial: some View {
    Circle()
      .fill(isActive ? accentColor : Color.clear)
      .background(.ultraThinMaterial, in: Circle())
      .overlay {
        Circle()
          .fill(isActive ? Color.clear : (colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.32)))
      }
  }

  private var circleStroke: some View {
    Circle()
      .stroke(
        isActive ? accentColor.opacity(0.78) : Color.oeBorder.opacity(0.32),
        lineWidth: 1
      )
  }
}

struct NativeComposerChipSurface<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme

  var accentColor: Color? = nil
  @ViewBuilder var content: Content

  var body: some View {
    if #available(iOS 26.0, *) {
      content
        .background(chipMaterial)
        .glassEffect(.regular.tint(chipTint), in: .capsule)
        .overlay(chipStroke)
    } else {
      content
        .background(chipMaterial)
        .overlay(chipStroke)
    }
  }

  private var chipTint: Color {
    if let accentColor {
      return accentColor.opacity(colorScheme == .dark ? 0.2 : 0.14)
    }
    return colorScheme == .dark ? Color.white.opacity(0.07) : Color.white.opacity(0.16)
  }

  private var chipMaterial: some View {
    Capsule(style: .continuous)
      .fill(.ultraThinMaterial)
      .overlay {
        Capsule(style: .continuous)
          .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.32))
      }
  }

  private var chipStroke: some View {
    Capsule(style: .continuous)
      .stroke(accentColor?.opacity(0.34) ?? Color.oeBorder.opacity(0.28), lineWidth: 1)
  }
}
