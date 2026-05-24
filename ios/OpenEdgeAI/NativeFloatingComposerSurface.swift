import SwiftUI

let nativeComposerInputCornerRadius: CGFloat = 30
let nativeComposerInlineControlSize: CGFloat = 40
let nativeComposerSubmitControlSize: CGFloat = 42
let nativeComposerScrollBottomPadding: CGFloat = 134

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
            .black.opacity(0.56),
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
      ? Color.black.opacity(0.12)
      : Color.white.opacity(0.16)
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
    content
      .disabled(isDisabled)
      .background(surfaceFill)
      .overlay(surfaceHighlight)
      .overlay(surfaceStroke)
      .overlay(focusRing)
      .shadow(color: ambientShadow, radius: 14, x: 0, y: 8)
      .opacity(isDisabled ? 0.48 : 1)
      .contentShape(RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius, style: .continuous))
      .onHover { isHovered = !isDisabled && $0 }
      .animation(.easeOut(duration: 0.16), value: isHovered)
      .animation(.easeOut(duration: 0.16), value: isFocused)
      .animation(.easeOut(duration: 0.16), value: isError)
  }

  private var surfaceOpacity: Double {
    if colorScheme == .dark {
      return isHovered || isFocused ? 0.12 : 0.08
    }
    return isHovered || isFocused ? 0.74 : 0.62
  }

  private var ambientShadow: Color {
    if isError || isFocused {
      return Color.black.opacity(colorScheme == .dark ? 0.22 : 0.12)
    }
    return colorScheme == .dark
      ? Color.black.opacity(0.18)
      : Color.black.opacity(0.08)
  }

  private var borderColor: Color {
    if isError {
      return Color.oeDestructive.opacity(0.55)
    }
    if isFocused {
      return accentColor.opacity(0.45)
    }
    if isHovered {
      return Color.white.opacity(colorScheme == .dark ? 0.24 : 0.9)
    }
    return Color.white.opacity(colorScheme == .dark ? 0.16 : 0.74)
  }

  private var surfaceFill: some View {
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
                Color.white.opacity(colorScheme == .dark ? 0.16 : 0.46),
                Color.white.opacity(colorScheme == .dark ? 0.04 : 0.12),
                Color.clear
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }
  }

  private var surfaceHighlight: some View {
    RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius - 1, style: .continuous)
      .inset(by: 1)
      .stroke(
        LinearGradient(
          colors: [
            Color.white.opacity(colorScheme == .dark ? 0.16 : 0.56),
            Color.white.opacity(0.02),
            Color.black.opacity(colorScheme == .dark ? 0.1 : 0.04)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        lineWidth: 0.8
      )
      .allowsHitTesting(false)
  }

  private var surfaceStroke: some View {
    RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius, style: .continuous)
      .stroke(
        LinearGradient(
          colors: [
            Color.white.opacity(colorScheme == .dark ? 0.22 : 0.82),
            borderColor,
            Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        lineWidth: 1
      )
      .allowsHitTesting(false)
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
