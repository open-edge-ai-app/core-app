import SwiftUI

struct NativePixelTrail: View {
  var color: Color
  var variant: Int
  var motion: NativeOnboardingMotion

  var body: some View {
    GeometryReader { proxy in
      ForEach(0..<10, id: \.self) { index in
        let phase = CGFloat(index) / 9
        Rectangle()
          .fill(color.opacity(0.08 + Double(index % 3) * 0.025))
          .frame(width: index.isMultiple(of: 3) ? 10 : 6, height: index.isMultiple(of: 3) ? 10 : 6)
          .offset(
            x: phase * proxy.size.width - proxy.size.width / 2 + CGFloat(pixelXOffset(index)),
            y: pixelY(phase: phase, height: proxy.size.height) + motion.float(3, speed: 0.18, offset: Double(index) * 0.11)
          )
      }
    }
  }

  private func pixelXOffset(_ index: Int) -> Int {
    switch variant {
    case 1:
      return index.isMultiple(of: 2) ? 10 : -4
    case 2:
      return index < 5 ? -10 : 8
    case 3:
      return index.isMultiple(of: 3) ? -14 : 7
    default:
      return index.isMultiple(of: 2) ? -6 : 6
    }
  }

  private func pixelY(phase: CGFloat, height: CGFloat) -> CGFloat {
    let step = CGFloat(Int((phase * 5).rounded()))
    switch variant {
    case 1:
      return -height * 0.30 + step * height * 0.13
    case 2:
      return height * 0.24 - step * height * 0.10
    case 3:
      return -height * 0.12 + abs(phase - 0.5) * height * 0.70
    default:
      return -height * 0.18 + step * height * 0.08
    }
  }
}

struct NativePixelCornerBlocks: View {
  var color: Color

  var body: some View {
    VStack {
      HStack {
        corner
        Spacer()
        corner
      }
      Spacer()
      HStack {
        corner
        Spacer()
        corner
      }
    }
  }

  private var corner: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 4) {
        Rectangle().frame(width: 8, height: 8)
        Rectangle().frame(width: 5, height: 5)
      }
      Rectangle().frame(width: 5, height: 5)
    }
    .foregroundColor(color.opacity(0.14))
  }
}

struct NativePixelTail: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.minY))
    path.closeSubpath()
    return path
  }
}

struct NativeSketchSpinner: View {
  var motion: NativeOnboardingMotion

  var body: some View {
    Circle()
      .trim(from: 0.08, to: 0.72)
      .stroke(.white.opacity(0.84), style: StrokeStyle(lineWidth: 3, lineCap: .square))
      .rotationEffect(.degrees(motion.rotation(speed: 0.86)))
  }
}

struct NativeSketchSendButton: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    Rectangle()
      .fill(accentColor.color)
      .frame(width: 30, height: 30)
      .overlay {
        Image(systemName: "arrow.up")
          .font(.system(size: 14, weight: .black))
          .foregroundColor(accentColor.foregroundColor)
          .offset(y: motion.float(1.5, speed: 0.48, offset: 0.4))
      }
  }
}

private struct NativePixelPanel: ViewModifier {
  var background: Color
  var border: Color

  func body(content: Content) -> some View {
    content
      .background(background)
      .overlay {
        Rectangle()
          .stroke(border, lineWidth: 2)
      }
      .overlay(alignment: .topLeading) {
        Rectangle()
          .fill(border.opacity(0.90))
          .frame(width: 5, height: 5)
          .offset(x: -1, y: -1)
      }
      .overlay(alignment: .bottomTrailing) {
        Rectangle()
          .fill(border.opacity(0.72))
          .frame(width: 5, height: 5)
          .offset(x: 1, y: 1)
      }
  }
}

extension View {
  func nativePixelPanel(background: Color, border: Color) -> some View {
    modifier(NativePixelPanel(background: background, border: border))
  }
}
