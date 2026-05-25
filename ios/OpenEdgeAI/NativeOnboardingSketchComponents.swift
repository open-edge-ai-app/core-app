import SwiftUI

struct NativeOnboardingSketchStage: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 32, style: .continuous)
        .fill(Color.oeSurface.opacity(0.18))

      ForEach(0..<7, id: \.self) { index in
        NativeSketchCurve(variant: index % 4)
          .stroke(
            (index.isMultiple(of: 2) ? accentColor.color : Color.oeText)
              .opacity(index.isMultiple(of: 2) ? 0.06 : 0.04),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
          )
          .frame(width: CGFloat(90 + index * 18), height: CGFloat(44 + index * 9))
          .rotationEffect(.degrees(Double(index * 11)))
          .offset(
            x: CGFloat(index * 17 - 54) + motion.float(4, speed: 0.18, offset: Double(index) * 0.17),
            y: CGFloat(index * 13 - 48) + motion.float(4, speed: 0.20, offset: Double(index) * 0.13)
          )
      }
    }
  }
}

struct NativeOnboardingPetActor: View {
  var pet: NativeDynamicIslandPet
  var petMotion: NativeDynamicIslandPetMotion
  var size: CGFloat

  var body: some View {
    ZStack(alignment: .bottom) {
      Ellipse()
        .fill(Color.oeText.opacity(0.08))
        .frame(width: size * 0.72, height: max(7, size * 0.10))
        .offset(y: size * 0.38)

      NativeDynamicIslandPetView(pet: pet, motion: petMotion, size: size)
        .frame(width: size + 12, height: size + 10)
    }
    .frame(width: size + 18, height: size + 18)
  }
}

struct NativeSketchBubble: View {
  var text: String
  var accentColor: NativeAccentColor
  var isAccent: Bool

  var body: some View {
    Text(text)
      .font(.system(size: 15, weight: .heavy))
      .foregroundColor(isAccent ? accentColor.foregroundColor : .oeText)
      .lineLimit(1)
      .padding(.horizontal, 16)
      .frame(height: 40)
      .background(
        Capsule(style: .continuous)
          .fill(isAccent ? accentColor.color : Color.oeBackground.opacity(0.70))
      )
      .overlay(alignment: .bottomLeading) {
        NativeSketchTail()
          .fill(isAccent ? accentColor.color : Color.oeBackground.opacity(0.70))
          .frame(width: 18, height: 14)
          .offset(x: 12, y: 7)
      }
  }
}

struct NativeSketchPromptStrip: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "plus")
        .font(.system(size: 16, weight: .heavy))
      RoundedRectangle(cornerRadius: 3, style: .continuous)
        .fill(Color.oeMutedText.opacity(0.28))
        .frame(height: 8)
        .overlay(alignment: .leading) {
          RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(accentColor.color.opacity(0.74))
            .frame(width: motion.progress(from: 42, to: 118, speed: 0.40, offset: 0.22), height: 8)
        }
      NativeSketchSendButton(accentColor: accentColor, motion: motion)
    }
    .foregroundColor(.oeText)
    .padding(.horizontal, 16)
    .frame(height: 46)
    .background(Color.oeBackground.opacity(0.62), in: Capsule(style: .continuous))
  }
}

struct NativeSketchTaskRow: View {
  var title: String
  var time: String
  var isDone: Bool
  var accentColor: NativeAccentColor

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
        .font(.system(size: 21, weight: .semibold))
        .foregroundColor(isDone ? accentColor.color : .oeMutedText)

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 14, weight: .heavy))
          .foregroundColor(.oeText)
        Text(time)
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(.oeMutedText)
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .frame(width: 174, height: 58)
    .background(Color.oeBackground.opacity(0.54), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
    .overlay {
      NativeSketchRoundedRect()
        .stroke(Color.oeText.opacity(0.13), style: NativeSketchStyle.thin)
        .padding(2)
    }
  }
}

struct NativeOnboardingWandPet: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    ZStack(alignment: .topTrailing) {
      NativeOnboardingPetActor(pet: .stacky, petMotion: .running, size: 72)

      Rectangle()
        .fill(Color.oeText)
        .frame(width: 2, height: 36)
        .rotationEffect(.degrees(44 + motion.degrees(12, speed: 0.72)))
        .offset(x: 10, y: 4)

      ForEach(0..<5, id: \.self) { index in
        Image(systemName: "sparkle")
          .font(.system(size: index == 0 ? 11 : 7, weight: .bold))
          .foregroundColor(accentColor.color)
          .offset(x: CGFloat(index * 10 - 18), y: CGFloat(index.isMultiple(of: 2) ? -14 : 2))
          .scaleEffect(motion.progress(from: 0.76, to: 1.24, speed: 0.72, offset: Double(index) * 0.17))
          .opacity(motion.opacity(from: 0.42, to: 1, speed: 0.72, offset: Double(index) * 0.17))
      }
    }
  }
}

struct NativeSketchPaperNote: View {
  var icon: String
  var title: String

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 19, weight: .bold))
      Text(title)
        .font(.system(size: 10, weight: .heavy))
    }
    .foregroundColor(.oeText)
    .frame(maxWidth: .infinity)
    .frame(height: 68)
    .background(Color.oeBackground.opacity(0.50), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .rotationEffect(.degrees(icon == "paperclip" ? -2 : 2))
  }
}

struct NativeSketchFolder: View {
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(accentColor.color.opacity(0.16))
        .frame(height: 86)
        .offset(y: 12)

      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .fill(accentColor.color.opacity(0.20))
        .frame(width: 78, height: 26)
        .offset(x: 18)

      VStack(alignment: .leading, spacing: 6) {
        Text("Project")
          .font(.system(size: 17, weight: .black))
          .foregroundColor(.oeText)
        Text("context flows into one place")
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(.oeSecondaryText)
      }
      .padding(.horizontal, 22)
      .padding(.top, 34)
    }
    .frame(height: 112)
    .overlay {
      NativeSketchRoundedRect()
        .stroke(accentColor.color.opacity(0.24), style: NativeSketchStyle.thin)
        .padding(.top, 12)
    }
  }
}

struct NativeSketchIslandPill: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    Capsule(style: .continuous)
      .fill(Color.oeText)
      .frame(width: 198, height: 56)
      .overlay {
        HStack(spacing: 14) {
          NativeDynamicIslandPetView(pet: .flux, motion: .running, size: 34)
            .frame(width: 42, height: 38)

          ZStack(alignment: .leading) {
            Capsule(style: .continuous)
              .fill(Color.white.opacity(0.22))
              .frame(width: 94, height: 5)
            Capsule(style: .continuous)
              .fill(accentColor.color)
              .frame(width: motion.progress(from: 28, to: 90, speed: 0.58), height: 5)
          }

          NativeSketchSpinner(motion: motion)
            .frame(width: 18, height: 18)
        }
      }
  }
}

struct NativeSketchProgressPanel: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    VStack(spacing: 10) {
      HStack(spacing: 6) {
        ForEach(0..<3, id: \.self) { index in
          Capsule(style: .continuous)
            .fill(index == 0 ? accentColor.color : Color.oeMutedText.opacity(0.24))
            .frame(width: motion.progress(from: 18, to: 46, speed: 0.42, offset: Double(index) * 0.24), height: 7)
        }
      }

      NativeSketchCaption(text: "keeps working quietly")
    }
    .padding(.horizontal, 18)
    .frame(height: 62)
    .background(Color.oeBackground.opacity(0.52), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
  }
}

private struct NativeSketchSendButton: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    Circle()
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

struct NativeSketchCaption: View {
  var text: String

  var body: some View {
    Text(text)
      .font(.system(size: 12, weight: .heavy))
      .foregroundColor(.oeSecondaryText)
      .padding(.horizontal, 13)
      .frame(height: 32)
      .background(Color.oeBackground.opacity(0.46), in: Capsule(style: .continuous))
  }
}

enum NativeSketchStyle {
  static let thin = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
  static let thick = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
}

struct NativeSketchCurve: Shape {
  var variant: Int

  func path(in rect: CGRect) -> Path {
    var path = Path()
    switch variant {
    case 0:
      path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.midY))
      path.addCurve(
        to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.midY + rect.height * 0.10),
        control1: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.10),
        control2: CGPoint(x: rect.maxX - rect.width * 0.28, y: rect.maxY - rect.height * 0.10)
      )
    case 1:
      path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY - rect.height * 0.22))
      path.addCurve(
        to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.minY + rect.height * 0.24),
        control1: CGPoint(x: rect.minX + rect.width * 0.34, y: rect.maxY + rect.height * 0.08),
        control2: CGPoint(x: rect.maxX - rect.width * 0.32, y: rect.minY - rect.height * 0.08)
      )
    case 2:
      path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.22))
      path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + rect.height * 0.18))
      path.addCurve(
        to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.maxY - rect.height * 0.18),
        control1: CGPoint(x: rect.maxX + rect.width * 0.04, y: rect.midY - rect.height * 0.12),
        control2: CGPoint(x: rect.maxX - rect.width * 0.02, y: rect.midY + rect.height * 0.24)
      )
      path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.maxY - rect.height * 0.16))
    default:
      path.move(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.midY))
      path.addCurve(
        to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.midY),
        control1: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.minY),
        control2: CGPoint(x: rect.maxX - rect.width * 0.30, y: rect.maxY)
      )
    }
    return path
  }
}

private struct NativeSketchRoundedRect: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let radius: CGFloat = min(20, min(rect.width, rect.height) * 0.24)
    let insetRect = rect.insetBy(dx: 1.5, dy: 1.5)
    path.addRoundedRect(in: insetRect, cornerSize: CGSize(width: radius, height: radius))
    return path
  }
}

private struct NativeSketchTail: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addCurve(
      to: CGPoint(x: rect.maxX, y: rect.maxY),
      control1: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY * 0.82),
      control2: CGPoint(x: rect.maxX * 0.54, y: rect.maxY)
    )
    path.addCurve(
      to: CGPoint(x: rect.minX + rect.width * 0.34, y: rect.minY + rect.height * 0.18),
      control1: CGPoint(x: rect.maxX * 0.54, y: rect.maxY * 0.72),
      control2: CGPoint(x: rect.minX + rect.width * 0.44, y: rect.midY)
    )
    path.closeSubpath()
    return path
  }
}

private struct NativeSketchSpinner: View {
  var motion: NativeOnboardingMotion

  var body: some View {
    Circle()
      .trim(from: 0.08, to: 0.72)
      .stroke(.white.opacity(0.84), style: StrokeStyle(lineWidth: 3, lineCap: .round))
      .rotationEffect(.degrees(motion.rotation(speed: 0.86)))
  }
}
