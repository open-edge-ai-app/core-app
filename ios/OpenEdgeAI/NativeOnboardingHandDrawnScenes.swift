import SwiftUI

struct NativeOnboardingChatSketchScene: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    ZStack {
      NativePixelTrail(color: accentColor.color, variant: 1, motion: motion)
        .frame(width: 226, height: 122)
        .offset(x: 18, y: -30)

      VStack(spacing: 10) {
        NativeHandDrawnUserBubble(
          label: "You",
          text: "Can you explain edge AI simply?",
          accentColor: accentColor
        )
        .padding(.leading, 64)

        HStack(alignment: .top, spacing: 10) {
          NativeOnboardingPetActor(pet: .orbit, petMotion: .resting, size: 66)
            .rotationEffect(.degrees(motion.degrees(2.6, speed: 0.34)))
            .offset(x: motion.float(3, speed: 0.36), y: motion.float(6, speed: 0.42) + 26)

          NativeHandDrawnAnswerCard(accentColor: accentColor, motion: motion)
        }
      }
      .padding(.horizontal, 22)
      .offset(y: -2)
    }
  }
}

struct NativeOnboardingTodoSketchScene: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    ZStack {
      NativePixelTrail(color: accentColor.color, variant: 2, motion: motion)
        .frame(width: 238, height: 136)
        .offset(x: -10, y: 8)

      VStack(spacing: 12) {
        NativeHandDrawnUserBubble(
          label: "Message",
          text: "Remind me to call Alex at 4 PM.",
          accentColor: accentColor
        )
        .frame(width: 246)

        HStack(alignment: .center, spacing: 12) {
          NativeHandDrawnTodoCard(accentColor: accentColor, motion: motion)

          NativeHandDrawnWandPet(accentColor: accentColor, motion: motion)
            .offset(x: motion.float(4, speed: 0.42), y: motion.float(7, speed: 0.54))
        }
      }
      .padding(.horizontal, 22)
      .offset(y: 2)
    }
  }
}

struct NativeOnboardingProjectSketchScene: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    ZStack {
      NativePixelTrail(color: Color.oeText, variant: 0, motion: motion)
        .frame(width: 246, height: 140)
        .offset(x: 6, y: -14)

      ZStack(alignment: .top) {
        NativeHandDrawnProjectFolder(accentColor: accentColor)
          .offset(y: 28)

        HStack(spacing: 132) {
          NativeOnboardingPetActor(pet: .luma, petMotion: .running, size: 54)
            .offset(x: motion.float(8, speed: 0.45, offset: 0.12), y: motion.float(4, speed: 0.42, offset: 0.32))
          NativeOnboardingPetActor(pet: .nullSignal, petMotion: .resting, size: 54)
            .offset(x: motion.float(6, speed: 0.40, offset: 0.70), y: motion.float(4, speed: 0.44, offset: 0.10))
        }
        .offset(y: -2)
      }
      .frame(height: 230)
      .padding(.horizontal, 22)
      .offset(y: -4)
    }
  }
}

struct NativeOnboardingIslandSketchScene: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    ZStack {
      NativePixelTrail(color: accentColor.color, variant: 3, motion: motion)
        .frame(width: 242, height: 144)
        .offset(y: 14)

      VStack(spacing: 14) {
        NativeHandDrawnIslandStatus(accentColor: accentColor, motion: motion)

        HStack(alignment: .center, spacing: 14) {
          NativeOnboardingPetActor(pet: .flux, petMotion: .running, size: 76)
            .rotationEffect(.degrees(motion.degrees(3, speed: 0.46, offset: 0.2)))
            .offset(y: motion.float(7, speed: 0.52, offset: 0.62))

          NativeHandDrawnQueueCard(accentColor: accentColor, motion: motion)
        }
      }
      .padding(.horizontal, 24)
      .offset(y: 0)
    }
  }
}

private struct NativeHandDrawnUserBubble: View {
  var label: String
  var text: String
  var accentColor: NativeAccentColor

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(label)
        .font(.system(size: 9, weight: .black))
        .foregroundColor(accentColor.foregroundColor.opacity(0.72))
      Text(text)
        .font(.system(size: 14, weight: .heavy))
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .foregroundColor(accentColor.foregroundColor)
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(width: 232, alignment: .leading)
    .nativeHandDrawnBubble(background: accentColor.color, ink: accentColor.foregroundColor.opacity(0.48), radius: 21)
    .rotationEffect(.degrees(1.1))
  }
}

private struct NativeHandDrawnAnswerCard: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 8) {
        NativeHandDrawnSparkleDot(accentColor: accentColor, motion: motion)
        Text("Edge AI runs the model on your device, so answers feel fast and private.")
          .font(.system(size: 12, weight: .black))
          .foregroundColor(.oeText)
          .lineLimit(4)
          .fixedSize(horizontal: false, vertical: true)
      }

      NativeHandDrawnBullet(text: "Private by default", color: accentColor.color)
      NativeHandDrawnBullet(text: "Works offline", color: .oeText)

      NativeHandDrawnTypingDots(accentColor: accentColor, motion: motion)
    }
    .padding(.horizontal, 13)
    .padding(.vertical, 11)
    .frame(width: 214, height: 136, alignment: .topLeading)
    .nativeHandDrawnBubble(background: Color.oeBackground.opacity(0.76), ink: accentColor.color.opacity(0.62), radius: 20)
    .rotationEffect(.degrees(-1.1))
  }
}

private struct NativeHandDrawnTodoCard: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(spacing: 8) {
        ZStack {
          Circle()
            .stroke(accentColor.color, lineWidth: 2.2)
            .frame(width: 22, height: 22)
          Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .black))
            .foregroundColor(accentColor.color)
        }
        Text("Call Alex")
          .font(.system(size: 17, weight: .black))
          .foregroundColor(.oeText)
      }

      NativeHandDrawnBullet(text: "Today, 4:00 PM", color: accentColor.color)
      NativeHandDrawnBullet(text: "Added to Todo", color: .oeSecondaryText)
    }
    .padding(.horizontal, 15)
    .padding(.vertical, 13)
    .frame(width: 180, height: 116, alignment: .leading)
    .nativeHandDrawnBubble(background: Color.oeBackground.opacity(0.74), ink: accentColor.color.opacity(0.58), radius: 22)
    .rotationEffect(.degrees(-1.4))
  }
}

private struct NativeHandDrawnWandPet: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    ZStack(alignment: .topTrailing) {
      NativeOnboardingPetActor(pet: .stacky, petMotion: .running, size: 74)

      Capsule()
        .fill(Color.oeText)
        .frame(width: 4, height: 38)
        .rotationEffect(.degrees(44 + motion.degrees(12, speed: 0.72)))
        .offset(x: 10, y: 4)

      ForEach(0..<5, id: \.self) { index in
        Circle()
          .fill(accentColor.color)
          .frame(width: index == 0 ? 8 : 5, height: index == 0 ? 8 : 5)
          .offset(x: CGFloat(index * 10 - 18), y: CGFloat(index.isMultiple(of: 2) ? -14 : 2))
          .scaleEffect(motion.progress(from: 0.76, to: 1.24, speed: 0.72, offset: Double(index) * 0.17))
          .opacity(motion.opacity(from: 0.42, to: 1, speed: 0.72, offset: Double(index) * 0.17))
      }
    }
  }
}

private struct NativeHandDrawnNote: View {
  var icon: String
  var title: String
  var accentColor: NativeAccentColor

  var body: some View {
    VStack(spacing: 7) {
      Image(systemName: icon)
        .font(.system(size: 18, weight: .bold))
      Text(title)
        .font(.system(size: 10, weight: .heavy))
    }
    .foregroundColor(.oeText)
    .frame(width: 72, height: 62)
    .nativeHandDrawnBubble(background: Color.oeBackground.opacity(0.62), ink: accentColor.color.opacity(0.38), radius: 15)
  }
}

private struct NativeHandDrawnProjectFolder: View {
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack(alignment: .top) {
      NativeHandDrawnFolderBack(accentColor: accentColor)
        .offset(y: 62)

      HStack(alignment: .bottom, spacing: 10) {
        NativeHandDrawnFolderSheet(icon: "text.alignleft", title: "Instructions", accentColor: accentColor)
          .rotationEffect(.degrees(-4))
          .offset(y: 2)
        NativeHandDrawnFolderSheet(icon: "paperclip", title: "Files", accentColor: accentColor)
          .rotationEffect(.degrees(2))
        NativeHandDrawnFolderSheet(icon: "bubble.left.and.bubble.right", title: "Chats", accentColor: accentColor)
          .rotationEffect(.degrees(4))
          .offset(y: 4)
      }
      .offset(y: 0)

      NativeHandDrawnFolderFront(accentColor: accentColor)
        .offset(y: 102)

      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 7) {
          Image(systemName: "folder.fill")
            .font(.system(size: 14, weight: .black))
            .foregroundColor(accentColor.color)
          Text("Workspace")
            .font(.system(size: 17, weight: .black))
            .foregroundColor(.oeText)
        }

        HStack(spacing: 6) {
          NativeHandDrawnContextChip(text: "notes", accentColor: accentColor, isAccent: false)
          NativeHandDrawnContextChip(text: "files", accentColor: accentColor, isAccent: true)
          NativeHandDrawnContextChip(text: "chats", accentColor: accentColor, isAccent: false)
        }

        NativeHandDrawnBullet(text: "Only this project context", color: accentColor.color)
      }
      .padding(.horizontal, 18)
      .padding(.top, 78)
      .frame(width: 256, alignment: .leading)
    }
    .frame(width: 270, height: 188)
  }
}

private struct NativeHandDrawnFolderSheet: View {
  var icon: String
  var title: String
  var accentColor: NativeAccentColor

  var body: some View {
    VStack(spacing: 7) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .black))
      Text(title)
        .font(.system(size: title.count > 8 ? 8 : 9, weight: .heavy))
        .lineLimit(1)
    }
    .foregroundColor(.oeText)
    .frame(width: 78, height: 64)
    .nativeHandDrawnBubble(background: Color.oeBackground.opacity(0.78), ink: accentColor.color.opacity(0.32), radius: 14)
  }
}

private struct NativeHandDrawnFolderBack: View {
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(accentColor.color.opacity(0.16))
        .frame(width: 258, height: 118)

      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(accentColor.color.opacity(0.26))
        .frame(width: 104, height: 28)
        .offset(x: 18, y: -13)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(accentColor.color.opacity(0.42), lineWidth: 1.4)
    }
  }
}

private struct NativeHandDrawnFolderFront: View {
  var accentColor: NativeAccentColor

  var body: some View {
    UnevenRoundedRectangle(
      topLeadingRadius: 18,
      bottomLeadingRadius: 24,
      bottomTrailingRadius: 24,
      topTrailingRadius: 18,
      style: .continuous
    )
    .fill(Color.oeBackground.opacity(0.82))
    .frame(width: 260, height: 74)
    .overlay {
      UnevenRoundedRectangle(
        topLeadingRadius: 18,
        bottomLeadingRadius: 24,
        bottomTrailingRadius: 24,
        topTrailingRadius: 18,
        style: .continuous
      )
      .stroke(Color.oeText.opacity(0.18), lineWidth: 1.4)
    }
    .overlay(alignment: .topLeading) {
      Capsule()
        .fill(accentColor.color.opacity(0.52))
        .frame(width: 46, height: 4)
        .rotationEffect(.degrees(-2))
        .offset(x: 20, y: 12)
    }
  }
}

private struct NativeHandDrawnContextChip: View {
  var text: String
  var accentColor: NativeAccentColor
  var isAccent: Bool

  var body: some View {
    Text(text)
      .font(.system(size: 9, weight: .black))
      .foregroundColor(isAccent ? accentColor.foregroundColor : .oeSecondaryText)
      .padding(.horizontal, 8)
      .frame(height: 20)
      .background(
        Capsule(style: .continuous)
          .fill(isAccent ? accentColor.color : Color.oeBackground.opacity(0.64))
      )
      .overlay {
        Capsule(style: .continuous)
          .stroke(isAccent ? Color.clear : Color.oeText.opacity(0.12), lineWidth: 1)
      }
  }
}

private struct NativeHandDrawnIslandStatus: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    HStack(spacing: 12) {
      NativeDynamicIslandPetView(pet: .flux, motion: .running, size: 34)
        .frame(width: 42, height: 38)

      VStack(alignment: .leading, spacing: 5) {
        Text("Writing in background")
          .font(.system(size: 11, weight: .black))
          .foregroundColor(.white.opacity(0.90))
        ZStack(alignment: .leading) {
          Capsule()
            .fill(Color.white.opacity(0.22))
            .frame(width: 102, height: 6)
          Capsule()
            .fill(accentColor.color)
            .frame(width: 72, height: 6)
        }
      }

      NativeSketchSpinner(motion: motion)
        .frame(width: 18, height: 18)
    }
    .padding(.horizontal, 14)
    .frame(width: 236, height: 60)
    .nativeHandDrawnBubble(background: Color.oeText, ink: accentColor.color.opacity(0.62), radius: 26)
    .rotationEffect(.degrees(0.8))
  }
}

private struct NativeHandDrawnQueueCard: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      NativeHandDrawnBullet(text: "Answering now", color: accentColor.color)
      NativeHandDrawnBullet(text: "Next in queue", color: .oeText)
      NativeHandDrawnTypingDots(accentColor: accentColor, motion: motion)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .frame(width: 154, height: 94, alignment: .leading)
    .nativeHandDrawnBubble(background: Color.oeBackground.opacity(0.72), ink: Color.oeText.opacity(0.22), radius: 20)
    .rotationEffect(.degrees(-1.6))
  }
}

private struct NativeHandDrawnSparkleDot: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    ZStack {
      Circle()
        .fill(accentColor.color.opacity(0.16))
      Image(systemName: "sparkles")
        .font(.system(size: 11, weight: .black))
        .foregroundColor(accentColor.color)
    }
    .frame(width: 24, height: 24)
  }
}

private struct NativeHandDrawnBullet: View {
  var text: String
  var color: Color

  var body: some View {
    HStack(spacing: 7) {
      Circle()
        .fill(color)
        .frame(width: 4, height: 4)
      Text(text)
        .font(.system(size: 11, weight: .heavy))
        .foregroundColor(.oeText)
        .lineLimit(1)
    }
  }
}

private struct NativeHandDrawnTypingDots: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    HStack(spacing: 5) {
      ForEach(0..<3, id: \.self) { index in
        Circle()
          .fill(accentColor.color.opacity(index == 0 ? 0.82 : 0.36))
          .frame(width: 5, height: 5)
      }
    }
  }
}
