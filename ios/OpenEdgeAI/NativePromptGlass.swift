import SwiftUI

let nativePromptInputCornerRadius: CGFloat = 24

struct NativePromptBlurBackdrop: View {
  var body: some View {
    Rectangle()
      .fill(.ultraThinMaterial)
      .overlay(Color.oeBackground.opacity(0.12))
      .mask(
        LinearGradient(
          colors: [
            Color.clear,
            Color.black.opacity(0.72),
            Color.black
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .allowsHitTesting(false)
  }
}

extension View {
  func nativePromptGlassPanel(
    cornerRadius: CGFloat,
    fill: Color = Color.oeSurface.opacity(0.3),
    borderColor: Color = Color.oeBorder.opacity(0.28),
    accentColor: Color? = nil,
    interactive: Bool = false
  ) -> some View {
    modifier(
      NativePromptGlassPanelModifier(
        cornerRadius: cornerRadius,
        fill: fill,
        borderColor: borderColor,
        accentColor: accentColor,
        interactive: interactive
      )
    )
  }

  func nativePromptGlassCircle(
    fill: Color = Color.oeSurface.opacity(0.32),
    borderColor: Color = Color.oeBorder.opacity(0.24),
    accentColor: Color? = nil,
    interactive: Bool = true
  ) -> some View {
    modifier(
      NativePromptGlassCircleModifier(
        fill: fill,
        borderColor: borderColor,
        accentColor: accentColor,
        interactive: interactive
      )
    )
  }

  func nativePromptGlassCapsule(
    fill: Color = Color.oeSurface.opacity(0.3),
    borderColor: Color = Color.oeBorder.opacity(0.22),
    accentColor: Color? = nil,
    interactive: Bool = false
  ) -> some View {
    modifier(
      NativePromptGlassCapsuleModifier(
        fill: fill,
        borderColor: borderColor,
        accentColor: accentColor,
        interactive: interactive
      )
    )
  }
}

private struct NativePromptGlassPanelModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  var cornerRadius: CGFloat
  var fill: Color
  var borderColor: Color
  var accentColor: Color?
  var interactive: Bool

  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      if interactive {
        content
          .background(panelBackground)
          .glassEffect(
            .regular.tint(glassTint).interactive(),
            in: .rect(cornerRadius: cornerRadius)
          )
          .overlay(panelStroke)
      } else {
        content
          .background(panelBackground)
          .glassEffect(
            .regular.tint(glassTint),
            in: .rect(cornerRadius: cornerRadius)
          )
          .overlay(panelStroke)
      }
    } else {
      content
        .background(panelBackground)
        .overlay(panelStroke)
    }
  }

  private var glassTint: Color {
    if let accentColor {
      return accentColor.opacity(colorScheme == .dark ? 0.18 : 0.12)
    }
    return fill.opacity(colorScheme == .dark ? 0.52 : 0.68)
  }

  private var panelBackground: some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      .fill(.ultraThinMaterial)
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(fill)
      }
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(
            LinearGradient(
              colors: [
                Color.white.opacity(colorScheme == .dark ? 0.16 : 0.38),
                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.15),
                Color.clear
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }
  }

  private var panelStroke: some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      .stroke(
        LinearGradient(
          colors: [
            Color.white.opacity(colorScheme == .dark ? 0.2 : 0.58),
            borderColor,
            Color.black.opacity(colorScheme == .dark ? 0.24 : 0.05)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        lineWidth: 1
      )
  }
}

private struct NativePromptGlassCircleModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  var fill: Color
  var borderColor: Color
  var accentColor: Color?
  var interactive: Bool

  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      if interactive {
        content
          .background(circleBackground)
          .glassEffect(.regular.tint(glassTint).interactive(), in: .circle)
          .overlay(circleStroke)
      } else {
        content
          .background(circleBackground)
          .glassEffect(.regular.tint(glassTint), in: .circle)
          .overlay(circleStroke)
      }
    } else {
      content
        .background(circleBackground)
        .overlay(circleStroke)
    }
  }

  private var glassTint: Color {
    if let accentColor {
      return accentColor.opacity(colorScheme == .dark ? 0.3 : 0.22)
    }
    return fill.opacity(colorScheme == .dark ? 0.56 : 0.72)
  }

  private var circleBackground: some View {
    Circle()
      .fill(.ultraThinMaterial)
      .overlay {
        Circle()
          .fill(fill)
      }
      .overlay {
        Circle()
          .fill(
            LinearGradient(
              colors: [
                Color.white.opacity(colorScheme == .dark ? 0.16 : 0.42),
                Color.white.opacity(colorScheme == .dark ? 0.04 : 0.12),
                Color.clear
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }
  }

  private var circleStroke: some View {
    Circle()
      .stroke(
        LinearGradient(
          colors: [
            Color.white.opacity(colorScheme == .dark ? 0.2 : 0.56),
            borderColor
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        lineWidth: 1
      )
  }
}

private struct NativePromptGlassCapsuleModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  var fill: Color
  var borderColor: Color
  var accentColor: Color?
  var interactive: Bool

  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      if interactive {
        content
          .background(capsuleBackground)
          .glassEffect(.regular.tint(glassTint).interactive(), in: .capsule)
          .overlay(capsuleStroke)
      } else {
        content
          .background(capsuleBackground)
          .glassEffect(.regular.tint(glassTint), in: .capsule)
          .overlay(capsuleStroke)
      }
    } else {
      content
        .background(capsuleBackground)
        .overlay(capsuleStroke)
    }
  }

  private var glassTint: Color {
    if let accentColor {
      return accentColor.opacity(colorScheme == .dark ? 0.24 : 0.16)
    }
    return fill.opacity(colorScheme == .dark ? 0.5 : 0.66)
  }

  private var capsuleBackground: some View {
    Capsule(style: .continuous)
      .fill(.ultraThinMaterial)
      .overlay {
        Capsule(style: .continuous)
          .fill(fill)
      }
      .overlay {
        Capsule(style: .continuous)
          .fill(
            LinearGradient(
              colors: [
                Color.white.opacity(colorScheme == .dark ? 0.14 : 0.34),
                Color.white.opacity(colorScheme == .dark ? 0.04 : 0.12),
                Color.clear
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }
  }

  private var capsuleStroke: some View {
    Capsule(style: .continuous)
      .stroke(
        LinearGradient(
          colors: [
            Color.white.opacity(colorScheme == .dark ? 0.18 : 0.48),
            borderColor
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        lineWidth: 1
      )
  }
}
