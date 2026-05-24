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

  var isFocused: Bool
  var accentColor: Color
  @ViewBuilder var content: Content

  var body: some View {
    if #available(iOS 26.0, *) {
      content
        .background(inputMaterial)
        .glassEffect(
          .regular
            .tint(isFocused ? accentColor.opacity(0.1) : neutralGlassTint)
            .interactive(),
          in: .rect(cornerRadius: nativeComposerInputCornerRadius)
        )
        .overlay(inputStroke)
    } else {
      content
        .background(inputMaterial)
        .overlay(inputStroke)
    }
  }

  private var neutralGlassTint: Color {
    colorScheme == .dark
      ? Color.white.opacity(0.08)
      : Color.white.opacity(0.18)
  }

  private var inputMaterial: some View {
    RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius, style: .continuous)
      .fill(.ultraThinMaterial)
      .overlay {
        RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius, style: .continuous)
          .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.38))
      }
  }

  private var inputStroke: some View {
    RoundedRectangle(cornerRadius: nativeComposerInputCornerRadius, style: .continuous)
      .stroke(
        LinearGradient(
          colors: [
            Color.white.opacity(colorScheme == .dark ? 0.2 : 0.7),
            isFocused ? accentColor.opacity(0.7) : Color.oeBorder.opacity(0.34)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        lineWidth: 1
      )
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
