import SwiftUI

let nativeComposerInputCornerRadius: CGFloat = 24
let nativeComposerScrollBottomPadding: CGFloat = 154

struct NativeFloatingComposerBackdrop: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Rectangle()
      .fill(.ultraThinMaterial)
      .overlay(backdropTint)
      .mask(
        LinearGradient(
          colors: [
            .clear,
            .black.opacity(0.62),
            .black
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .allowsHitTesting(false)
  }

  private var backdropTint: Color {
    colorScheme == .dark
      ? Color.black.opacity(0.18)
      : Color.white.opacity(0.18)
  }
}

struct NativeComposerInputSurface<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var isHovered = false

  var isFocused: Bool
  var isDisabled: Bool = false
  var isError: Bool = false
  var accentColor: Color
  @ViewBuilder var content: Content

  var body: some View {
    if #available(iOS 26.0, *) {
      content
        .disabled(isDisabled)
        .background(inputMaterial)
        .glassEffect(
          .regular
            .tint(glassTint)
            .interactive(),
          in: .rect(cornerRadius: nativeComposerInputCornerRadius)
        )
        .overlay(inputReflection)
        .overlay(inputStroke)
        .overlay(focusRing)
        .shadow(color: shadowColor, radius: 18, x: 0, y: 8)
        .opacity(isDisabled ? 0.48 : 1)
        .onHover { isHovered = !isDisabled && $0 }
    } else {
      content
        .disabled(isDisabled)
        .background(inputMaterial)
        .overlay(inputReflection)
        .overlay(inputStroke)
        .overlay(focusRing)
        .shadow(color: shadowColor, radius: 18, x: 0, y: 8)
        .opacity(isDisabled ? 0.48 : 1)
        .onHover { isHovered = !isDisabled && $0 }
    }
  }

  private var surfaceOpacity: Double {
    if colorScheme == .dark {
      return isHovered || isFocused ? 0.1 : 0.08
    }
    return isHovered || isFocused ? 0.68 : 0.58
  }

  private var glassTint: Color {
    if isError {
      return Color.oeDestructive.opacity(colorScheme == .dark ? 0.18 : 0.12)
    }
    if isFocused {
      return accentColor.opacity(colorScheme == .dark ? 0.18 : 0.12)
    }
    return Color.white.opacity(colorScheme == .dark ? 0.08 : 0.1)
  }

  private var shadowColor: Color {
    if isError || isFocused {
      return Color.black.opacity(colorScheme == .dark ? 0.2 : 0.12)
    }
    return colorScheme == .dark
      ? Color.black.opacity(0.18)
      : Color.black.opacity(0.1)
  }

  private var borderColor: Color {
    if isError {
      return Color.oeDestructive.opacity(0.55)
    }
    if isFocused {
      return accentColor.opacity(0.45)
    }
    if isHovered {
      return Color.white.opacity(colorScheme == .dark ? 0.24 : 0.78)
    }
    return Color.white.opacity(colorScheme == .dark ? 0.16 : 0.66)
  }

  private var inputMaterial: some View {
    RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius, style: .continuous)
      .fill(.ultraThinMaterial)
      .overlay {
        RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius, style: .continuous)
          .fill(Color.white.opacity(surfaceOpacity))
      }
      .overlay {
        RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius, style: .continuous)
          .fill(
            LinearGradient(
              colors: [
                Color.white.opacity(colorScheme == .dark ? 0.12 : 0.34),
                Color.white.opacity(colorScheme == .dark ? 0.04 : 0.12),
                Color.clear
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }
  }

  private var inputReflection: some View {
    RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius - 1, style: .continuous)
      .inset(by: 1)
      .stroke(
        LinearGradient(
          colors: [
            Color.white.opacity(colorScheme == .dark ? 0.12 : 0.42),
            Color.white.opacity(0.02),
            Color.white.opacity(colorScheme == .dark ? 0.06 : 0.2)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        lineWidth: 0.8
      )
      .allowsHitTesting(false)
  }

  private var inputStroke: some View {
    RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius, style: .continuous)
      .stroke(
        LinearGradient(
          colors: [
            Color.white.opacity(colorScheme == .dark ? 0.2 : 0.7),
            borderColor,
            Color.black.opacity(colorScheme == .dark ? 0.18 : 0.05)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        lineWidth: 1
      )
  }

  private var focusRing: some View {
    RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius + 2, style: .continuous)
      .stroke(focusRingColor, lineWidth: focusRingWidth)
      .allowsHitTesting(false)
  }

  private var focusRingColor: Color {
    guard isFocused else {
      return .clear
    }
    return isError ? Color.oeDestructive.opacity(0.12) : accentColor.opacity(0.12)
  }

  private var focusRingWidth: CGFloat {
    isFocused ? 3 : 0
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
      .frame(width: 36, height: 36)
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
