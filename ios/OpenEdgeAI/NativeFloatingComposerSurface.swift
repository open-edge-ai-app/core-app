import SwiftUI

let nativeComposerInputCornerRadius: CGFloat = 30
let nativeComposerAttachControlSize: CGFloat = 52
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
      return Color.white.opacity(isFocused ? 0.1 : 0.07)
    }
    return Color.white.opacity(isFocused ? 0.22 : 0.14)
  }

  private var glassHighlight: some View {
    RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius - 1, style: .continuous)
      .inset(by: 1)
      .stroke(
        LinearGradient(
          colors: [
            Color.white.opacity(colorScheme == .dark ? 0.14 : 0.4),
            Color.white.opacity(colorScheme == .dark ? 0.04 : 0.12),
            Color.black.opacity(colorScheme == .dark ? 0.1 : 0.04)
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
      return accentColor.opacity(0.36)
    }
    return Color.white.opacity(colorScheme == .dark ? 0.14 : 0.3)
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
        .shadow(color: inactiveCircleShadow, radius: isActive ? 0 : 8, x: 0, y: 2)
    } else {
      content
        .background(circleMaterial)
        .overlay(circleStroke)
        .shadow(color: inactiveCircleShadow, radius: isActive ? 0 : 8, x: 0, y: 2)
    }
  }

  private var neutralGlassTint: Color {
    colorScheme == .dark
      ? Color.white.opacity(0.1)
      : Color.white.opacity(0.26)
  }

  private var circleMaterial: some View {
    Circle()
      .fill(isActive ? accentColor : Color.clear)
      .background(.ultraThinMaterial, in: Circle())
      .overlay {
        Circle()
          .fill(isActive ? Color.clear : inactiveCircleTint)
      }
  }

  private var circleStroke: some View {
    Circle()
      .stroke(
        isActive ? accentColor.opacity(0.78) : inactiveCircleStroke,
        lineWidth: 1
      )
  }

  private var inactiveCircleTint: Color {
    colorScheme == .dark
      ? Color.white.opacity(0.12)
      : Color.black.opacity(0.14)
  }

  private var inactiveCircleStroke: Color {
    colorScheme == .dark
      ? Color.white.opacity(0.18)
      : Color.black.opacity(0.16)
  }

  private var inactiveCircleShadow: Color {
    colorScheme == .dark
      ? Color.black.opacity(0.18)
      : Color.black.opacity(0.08)
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
