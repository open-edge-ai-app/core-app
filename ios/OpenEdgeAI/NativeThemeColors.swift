import Foundation
import SwiftUI
import UIKit

extension Color {
  static var oeBackground: Color { Color(uiColor: .systemBackground) }
  static var oeGroupedBackground: Color { Color(uiColor: .systemGroupedBackground) }
  static var oeSurface: Color { Color(uiColor: .secondarySystemGroupedBackground) }
  static var oeElevatedSurface: Color { Color(uiColor: .tertiarySystemGroupedBackground) }
  static var oeText: Color { Color(uiColor: .label) }
  static var oeSecondaryText: Color { Color(uiColor: .secondaryLabel) }
  static var oeMutedText: Color { Color(uiColor: .tertiaryLabel) }
  static var oeSubtleFill: Color { Color(uiColor: .secondarySystemFill) }
  static var oeSoftFill: Color { Color(uiColor: .tertiarySystemFill) }
  static var oeBorder: Color { Color(uiColor: .separator) }
  static var oeSeparator: Color { Color(uiColor: .separator) }
  static var oeTaskCardSurface: Color {
    Color(uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? .secondarySystemGroupedBackground
        : .secondarySystemBackground
    })
  }
  static var oeTaskCardBorder: Color {
    Color(uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? .separator
        : UIColor.separator.withAlphaComponent(0.34)
    })
  }
  static var oeControlFill: Color { Color(uiColor: .label) }
  static var oeControlText: Color { Color(uiColor: .systemBackground) }
  static var oeDestructive: Color { Color(uiColor: .systemRed) }
  static var oeNowIndicator: Color { Color(uiColor: .systemRed) }
}

struct NativeGlassEffectContainer<Content: View>: View {
  var spacing: CGFloat = 16
  @ViewBuilder var content: Content

  var body: some View {
    if #available(iOS 26.0, *) {
      GlassEffectContainer(spacing: spacing) {
        content
      }
    } else {
      content
    }
  }
}

extension View {
  @ViewBuilder
  func nativeLiquidGlass(
    cornerRadius: CGFloat,
    tint: Color? = nil,
    interactive: Bool = false
  ) -> some View {
    if #available(iOS 26.0, *) {
      if let tint {
        if interactive {
          self.glassEffect(
            .regular.tint(tint).interactive(),
            in: .rect(cornerRadius: cornerRadius)
          )
        } else {
          self.glassEffect(
            .regular.tint(tint),
            in: .rect(cornerRadius: cornerRadius)
          )
        }
      } else if interactive {
        self.glassEffect(
          .regular.interactive(),
          in: .rect(cornerRadius: cornerRadius)
        )
      } else {
        self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
      }
    } else {
      self.background(
        .ultraThinMaterial,
        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      )
    }
  }

  @ViewBuilder
  func nativeLiquidGlassCapsule(
    tint: Color? = nil,
    interactive: Bool = false
  ) -> some View {
    if #available(iOS 26.0, *) {
      if let tint {
        if interactive {
          self.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
        } else {
          self.glassEffect(.regular.tint(tint), in: .capsule)
        }
      } else if interactive {
        self.glassEffect(.regular.interactive(), in: .capsule)
      } else {
        self.glassEffect(.regular, in: .capsule)
      }
    } else {
      self.background(.ultraThinMaterial, in: Capsule(style: .continuous))
    }
  }

  @ViewBuilder
  func nativeLiquidGlassCircle(
    tint: Color? = nil,
    interactive: Bool = false
  ) -> some View {
    if #available(iOS 26.0, *) {
      if let tint {
        if interactive {
          self.glassEffect(.regular.tint(tint).interactive(), in: .circle)
        } else {
          self.glassEffect(.regular.tint(tint), in: .circle)
        }
      } else if interactive {
        self.glassEffect(.regular.interactive(), in: .circle)
      } else {
        self.glassEffect(.regular, in: .circle)
      }
    } else {
      self.background(.ultraThinMaterial, in: Circle())
    }
  }

  func nativeGlassStroke(
    cornerRadius: CGFloat,
    color: Color = Color.oeBorder.opacity(0.52)
  ) -> some View {
    overlay(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .stroke(color, lineWidth: 1)
    )
  }
}
