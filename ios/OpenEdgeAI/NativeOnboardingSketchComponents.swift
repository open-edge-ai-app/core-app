import SwiftUI

struct NativeOnboardingSketchStage: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Rectangle()
          .fill(Color.oeSurface.opacity(0.11))

        ForEach(0..<11, id: \.self) { column in
          ForEach(0..<8, id: \.self) { row in
            let isAccent = (column + row).isMultiple(of: 5)
            Capsule()
              .fill((isAccent ? accentColor.color : Color.oeText).opacity(isAccent ? 0.08 : 0.035))
              .frame(width: isAccent ? 11 : 7, height: isAccent ? 3 : 2)
              .rotationEffect(.degrees(Double((column - row) * 8)))
              .offset(
                x: CGFloat(column) * proxy.size.width / 10 - proxy.size.width / 2 + motion.float(2, speed: 0.12, offset: Double(row) * 0.11),
                y: CGFloat(row) * proxy.size.height / 7 - proxy.size.height / 2 + motion.float(2, speed: 0.14, offset: Double(column) * 0.09)
              )
          }
        }

        NativePixelCornerBlocks(color: accentColor.color)
          .padding(18)
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
      Rectangle()
        .fill(Color.oeText.opacity(0.07))
        .frame(width: size * 0.62, height: max(5, size * 0.08))
        .offset(y: size * 0.38)

      NativeDynamicIslandPetView(pet: pet, motion: petMotion, size: size)
        .frame(width: size + 12, height: size + 10)
    }
    .frame(width: size + 18, height: size + 18)
  }
}

struct NativeSketchSceneBadge: View {
  var icon: String
  var title: String
  var accentColor: NativeAccentColor

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: icon)
        .font(.system(size: 12, weight: .black))
      Text(title)
        .font(.system(size: 12, weight: .black))
        .lineLimit(1)
    }
    .foregroundColor(.oeText)
    .padding(.horizontal, 12)
    .frame(height: 32)
    .nativeHandDrawnBubble(background: Color.oeBackground.opacity(0.72), ink: accentColor.color.opacity(0.72), radius: 10)
    .rotationEffect(.degrees(-0.8))
  }
}

struct NativeSketchBubble: View {
  var icon: String?
  var text: String
  var accentColor: NativeAccentColor
  var isAccent: Bool

  init(icon: String? = nil, text: String, accentColor: NativeAccentColor, isAccent: Bool) {
    self.icon = icon
    self.text = text
    self.accentColor = accentColor
    self.isAccent = isAccent
  }

  var body: some View {
    HStack(spacing: 7) {
      if let icon {
        Image(systemName: icon)
          .font(.system(size: 12, weight: .black))
      }

      Text(text)
        .font(.system(size: 15, weight: .heavy))
        .lineLimit(1)
    }
    .foregroundColor(isAccent ? accentColor.foregroundColor : .oeText)
    .padding(.horizontal, 15)
    .frame(height: 40)
    .nativePixelPanel(
      background: isAccent ? accentColor.color : Color.oeBackground.opacity(0.72),
      border: isAccent ? Color.oeText.opacity(0.12) : Color.oeText.opacity(0.10)
    )
    .overlay(alignment: .bottomLeading) {
      NativePixelTail()
        .fill(isAccent ? accentColor.color : Color.oeBackground.opacity(0.72))
        .frame(width: 18, height: 14)
        .offset(x: 12, y: 10)
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

      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 6) {
          Text("Prompt")
            .font(.system(size: 9, weight: .black))
            .foregroundColor(.oeSecondaryText)
          Image(systemName: "sparkles")
            .font(.system(size: 9, weight: .black))
            .foregroundColor(accentColor.color)
          Text("AI")
            .font(.system(size: 9, weight: .black))
            .foregroundColor(accentColor.color)
        }

        ZStack(alignment: .leading) {
          Rectangle()
            .fill(Color.oeMutedText.opacity(0.20))
            .frame(height: 8)
          Rectangle()
            .fill(accentColor.color.opacity(0.78))
            .frame(width: motion.progress(from: 42, to: 118, speed: 0.40, offset: 0.22), height: 8)
        }
      }

      NativeSketchSendButton(accentColor: accentColor, motion: motion)
    }
    .foregroundColor(.oeText)
    .padding(.horizontal, 16)
    .frame(height: 52)
    .nativePixelPanel(background: Color.oeBackground.opacity(0.64), border: Color.oeText.opacity(0.10))
  }
}

struct NativePixelChatQuestion: View {
  var accentColor: NativeAccentColor

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("You")
        .font(.system(size: 9, weight: .black))
        .foregroundColor(accentColor.foregroundColor.opacity(0.74))
      Text("Can you explain edge AI simply?")
        .font(.system(size: 14, weight: .heavy))
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .foregroundColor(accentColor.foregroundColor)
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(width: 232, alignment: .leading)
    .nativeHandDrawnBubble(background: accentColor.color, ink: accentColor.foregroundColor.opacity(0.48), radius: 21)
    .rotationEffect(.degrees(1.2))
    .overlay(alignment: .bottomTrailing) {
      NativePixelTail()
        .fill(accentColor.color)
        .frame(width: 16, height: 13)
        .scaleEffect(x: -1, y: 1)
        .offset(x: -14, y: 9)
    }
  }
}

struct NativePixelChatAnswer: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 8) {
        ZStack {
          Circle()
            .fill(accentColor.color.opacity(0.16))
          Image(systemName: "sparkles")
            .font(.system(size: 11, weight: .black))
            .foregroundColor(accentColor.color)
        }
        .frame(width: 24, height: 24)

        Text("Edge AI runs the model on your device, so answers feel fast and private.")
          .font(.system(size: 12, weight: .black))
          .foregroundColor(.oeText)
          .lineLimit(4)
          .fixedSize(horizontal: false, vertical: true)
      }

      NativePixelAnswerTextRow(number: "•", text: "Private by default", color: accentColor.color)
      NativePixelAnswerTextRow(number: "•", text: "Works offline", color: .oeText)

      HStack(spacing: 5) {
        ForEach(0..<3, id: \.self) { index in
          Circle()
            .fill(accentColor.color.opacity(motion.opacity(from: 0.28, to: 0.88, speed: 0.58, offset: Double(index) * 0.14)))
            .frame(width: 5, height: 5)
            .offset(y: motion.float(2, speed: 0.58, offset: Double(index) * 0.14))
        }
      }
      .padding(.top, 1)
    }
    .padding(.horizontal, 13)
    .padding(.vertical, 11)
    .frame(width: 214, height: 136, alignment: .topLeading)
    .nativeHandDrawnBubble(background: Color.oeBackground.opacity(0.76), ink: accentColor.color.opacity(0.62), radius: 20)
    .rotationEffect(.degrees(-1.1))
    .overlay(alignment: .leading) {
      NativePixelTail()
        .fill(Color.oeBackground.opacity(0.76))
        .frame(width: 16, height: 14)
        .rotationEffect(.degrees(180))
        .offset(x: -13, y: 30)
    }
  }
}

private struct NativePixelAnswerTextRow: View {
  var number: String
  var text: String
  var color: Color

  var body: some View {
    HStack(spacing: 7) {
      Text(number)
        .font(.system(size: 13, weight: .black))
        .foregroundColor(color)
        .frame(width: 12, alignment: .leading)
      Text(text)
        .font(.system(size: 11, weight: .heavy))
        .foregroundColor(.oeText)
        .lineLimit(1)
    }
  }
}

struct NativeSketchTaskRow: View {
  var title: String
  var time: String
  var isDone: Bool
  var accentColor: NativeAccentColor

  var body: some View {
    HStack(spacing: 10) {
      ZStack {
        Rectangle()
          .stroke(isDone ? accentColor.color : Color.oeMutedText, lineWidth: 2)
          .frame(width: 20, height: 20)
        if isDone {
          Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .black))
            .foregroundColor(accentColor.color)
        }
      }

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 14, weight: .heavy))
          .foregroundColor(.oeText)
        HStack(spacing: 5) {
          Image(systemName: "calendar.badge.clock")
            .font(.system(size: 9, weight: .black))
          Text(time)
            .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(.oeMutedText)
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .frame(width: 174, height: 58)
    .nativePixelPanel(background: Color.oeBackground.opacity(0.58), border: Color.oeText.opacity(0.13))
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
        .frame(width: 3, height: 36)
        .rotationEffect(.degrees(44 + motion.degrees(12, speed: 0.72)))
        .offset(x: 10, y: 4)

      ForEach(0..<5, id: \.self) { index in
        Rectangle()
          .fill(accentColor.color)
          .frame(width: index == 0 ? 8 : 5, height: index == 0 ? 8 : 5)
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
    .nativePixelPanel(background: Color.oeBackground.opacity(0.54), border: Color.oeText.opacity(0.10))
    .rotationEffect(.degrees(icon == "paperclip" ? -2 : 2))
  }
}

struct NativeSketchFolder: View {
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack(alignment: .topLeading) {
      Rectangle()
        .fill(accentColor.color.opacity(0.16))
        .frame(height: 92)
        .offset(y: 12)

      Rectangle()
        .fill(accentColor.color.opacity(0.22))
        .frame(width: 80, height: 26)
        .offset(x: 18)

      VStack(alignment: .leading, spacing: 7) {
        HStack(spacing: 7) {
          Image(systemName: "folder.fill")
            .font(.system(size: 16, weight: .black))
            .foregroundColor(accentColor.color)
          Text("Workspace")
            .font(.system(size: 17, weight: .black))
            .foregroundColor(.oeText)
        }

        NativeSketchContextLine(icon: "text.alignleft", text: "prompt + files + chats", color: .oeSecondaryText)
        NativeSketchContextLine(icon: "checkmark.seal.fill", text: "focused project memory", color: accentColor.color)
      }
      .padding(.horizontal, 22)
      .padding(.top, 32)
    }
    .frame(height: 118)
    .nativePixelPanel(background: Color.clear, border: accentColor.color.opacity(0.26))
  }
}

struct NativeSketchIslandPill: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    HStack(spacing: 12) {
      NativeDynamicIslandPetView(pet: .flux, motion: .running, size: 34)
        .frame(width: 42, height: 38)

      VStack(alignment: .leading, spacing: 5) {
        Text("Working")
          .font(.system(size: 11, weight: .black))
          .foregroundColor(.white.opacity(0.88))
        ZStack(alignment: .leading) {
          Rectangle()
            .fill(Color.white.opacity(0.22))
            .frame(width: 94, height: 5)
          Rectangle()
            .fill(accentColor.color)
            .frame(width: motion.progress(from: 28, to: 90, speed: 0.58), height: 5)
        }
      }

      NativeSketchSpinner(motion: motion)
        .frame(width: 18, height: 18)
    }
    .padding(.horizontal, 14)
    .frame(width: 210, height: 58)
    .nativePixelPanel(background: Color.oeText, border: accentColor.color.opacity(0.36))
  }
}

struct NativeSketchProgressPanel: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      NativeSketchQueuedStep(index: 1, label: "answering now", accentColor: accentColor)
      NativeSketchQueuedStep(index: 2, label: "queued follow-up", accentColor: accentColor)
    }
    .padding(.horizontal, 16)
    .frame(height: 66)
    .nativePixelPanel(background: Color.oeBackground.opacity(0.56), border: Color.oeText.opacity(0.10))
    .overlay(alignment: .bottomTrailing) {
      HStack(spacing: 5) {
        ForEach(0..<3, id: \.self) { index in
          Rectangle()
            .fill(index == 0 ? accentColor.color : Color.oeMutedText.opacity(0.24))
            .frame(width: motion.progress(from: 4, to: 8, speed: 0.46, offset: Double(index) * 0.18), height: 6)
        }
      }
      .padding(12)
    }
  }
}

struct NativeSketchFlowCaption: View {
  var text: String
  var accentColor: NativeAccentColor

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "arrow.triangle.branch")
        .font(.system(size: 12, weight: .black))
      Text(text)
        .font(.system(size: 12, weight: .black))
        .lineLimit(1)
    }
    .foregroundColor(.oeText)
    .padding(.horizontal, 14)
    .frame(height: 34)
    .nativePixelPanel(background: Color.oeBackground.opacity(0.58), border: accentColor.color.opacity(0.22))
  }
}

struct NativeSketchContextLine: View {
  var icon: String
  var text: String
  var color: Color

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 9, weight: .black))
      Text(text)
        .font(.system(size: 10, weight: .black))
        .lineLimit(1)
    }
    .foregroundColor(color)
  }
}

struct NativeSketchQueuedStep: View {
  var index: Int
  var label: String
  var accentColor: NativeAccentColor

  var body: some View {
    HStack(spacing: 8) {
      Text("\(index)")
        .font(.system(size: 10, weight: .black))
        .foregroundColor(accentColor.foregroundColor)
        .frame(width: 19, height: 19)
        .background(accentColor.color)
      Text(label)
        .font(.system(size: 11, weight: .black))
        .foregroundColor(.oeText)
      Spacer(minLength: 0)
    }
  }
}
