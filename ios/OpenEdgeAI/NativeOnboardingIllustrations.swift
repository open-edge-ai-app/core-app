import SwiftUI

enum NativeOnboardingScene {
  case workspace
  case todo
  case document
  case progress
}

struct NativeOnboardingIllustration: View {
  var scene: NativeOnboardingScene
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 30, style: .continuous)
        .fill(Color.oeSurface.opacity(0.72))
        .nativeLiquidGlass(cornerRadius: 30)
        .nativeGlassStroke(cornerRadius: 30, color: Color.oeBorder.opacity(0.16))

      switch scene {
      case .workspace:
        NativeOnboardingChatCoreScene(accentColor: accentColor)
      case .todo:
        NativeOnboardingTodoCoreScene(accentColor: accentColor)
      case .document:
        NativeOnboardingProjectCoreScene(accentColor: accentColor)
      case .progress:
        NativeOnboardingIslandCoreScene(accentColor: accentColor)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
  }
}

private struct NativeOnboardingChatCoreScene: View {
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack {
      NativeOnboardingSoftBlob(color: accentColor.color, alignment: .topTrailing)

      VStack(spacing: 18) {
        NativeOnboardingPetBadge(pet: .orbit, motion: .resting, label: "Noa", size: 82, accentColor: accentColor)

        VStack(spacing: 10) {
          NativeOnboardingBubble(
            text: "Ask privately",
            foreground: accentColor.foregroundColor,
            background: accentColor.color,
            alignment: .trailing
          )

          NativeOnboardingBubble(
            text: "Answer with context",
            foreground: .oeText,
            background: Color.oeBackground.opacity(0.84),
            alignment: .leading
          )
        }

        HStack(spacing: 8) {
          NativeOnboardingChip("ON DEVICE")
          NativeOnboardingChip("PRIVATE")
          NativeOnboardingChip("FOLLOW-UP")
        }
      }
      .padding(26)
    }
  }
}

private struct NativeOnboardingTodoCoreScene: View {
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack {
      NativeOnboardingSoftBlob(color: accentColor.color, alignment: .bottomTrailing)

      VStack(spacing: 16) {
        HStack(alignment: .bottom, spacing: 16) {
          VStack(spacing: 10) {
            NativeOnboardingTaskCard(title: "VP meeting", time: "4:00 PM", isDone: true, accentColor: accentColor)
            NativeOnboardingTaskCard(title: "Send summary", time: "Today", isDone: false, accentColor: accentColor)
          }

          NativeOnboardingWandPet(accentColor: accentColor)
        }

        NativeOnboardingArrowLabel(text: "Message → Todo")
      }
      .padding(24)
    }
  }
}

private struct NativeOnboardingProjectCoreScene: View {
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack {
      NativeOnboardingSoftBlob(color: accentColor.color, alignment: .topLeading)

      VStack(spacing: 18) {
        HStack(spacing: 10) {
          NativeOnboardingContextTile(icon: "text.alignleft", title: "Prompt")
          NativeOnboardingContextTile(icon: "doc", title: "Files")
          NativeOnboardingContextTile(icon: "bubble.left.and.bubble.right", title: "Chats")
        }

        Image(systemName: "arrow.down")
          .font(.system(size: 18, weight: .heavy))
          .foregroundColor(.oeMutedText)

        NativeOnboardingProjectFolder(accentColor: accentColor)

        HStack(spacing: 12) {
          NativeOnboardingPetBadge(pet: .nullSignal, motion: .resting, label: "Sia", size: 58, accentColor: accentColor)
          NativeOnboardingPetBadge(pet: .luma, motion: .running, label: "Lumi", size: 58, accentColor: accentColor)
        }
      }
      .padding(24)
    }
  }
}

private struct NativeOnboardingIslandCoreScene: View {
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack {
      NativeOnboardingSoftBlob(color: Color.oeText, alignment: .bottomLeading)

      VStack(spacing: 18) {
        NativeOnboardingIslandPill()

        VStack(spacing: 10) {
          Text("Working in background")
            .font(.system(size: 15, weight: .heavy))
            .foregroundColor(.oeText)

          ProgressView(value: 0.68)
            .tint(accentColor.color)
            .frame(width: 180)
        }
        .padding(18)
        .background(Color.oeBackground.opacity(0.82), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

        NativeOnboardingPetBadge(pet: .flux, motion: .running, label: "Rio", size: 68, accentColor: accentColor)
      }
      .padding(26)
    }
  }
}

private struct NativeOnboardingPetBadge: View {
  var pet: NativeDynamicIslandPet
  var motion: NativeDynamicIslandPetMotion
  var label: String
  var size: CGFloat
  var accentColor: NativeAccentColor

  var body: some View {
    VStack(spacing: 4) {
      NativeDynamicIslandPetView(pet: pet, motion: motion, size: size)
        .frame(width: size + 14, height: size + 10)

      Text(label)
        .font(.system(size: 10, weight: .black))
        .foregroundColor(.oeSecondaryText)
    }
    .padding(10)
    .background(Color.oeBackground.opacity(0.76), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .nativeGlassStroke(cornerRadius: 20, color: accentColor.color.opacity(0.12))
  }
}

private struct NativeOnboardingBubble: View {
  var text: String
  var foreground: Color
  var background: Color
  var alignment: Alignment

  var body: some View {
    Text(text)
      .font(.system(size: 15, weight: .heavy))
      .foregroundColor(foreground)
      .padding(.horizontal, 18)
      .frame(height: 42)
      .background(background, in: Capsule(style: .continuous))
      .frame(maxWidth: .infinity, alignment: alignment)
  }
}

private struct NativeOnboardingTaskCard: View {
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

      Spacer()
    }
    .padding(.horizontal, 14)
    .frame(width: 180, height: 60)
    .background(Color.oeBackground.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .nativeGlassStroke(cornerRadius: 18, color: Color.oeBorder.opacity(0.18))
  }
}

private struct NativeOnboardingWandPet: View {
  var accentColor: NativeAccentColor

  var body: some View {
    ZStack(alignment: .topTrailing) {
      NativeOnboardingPetBadge(pet: .stacky, motion: .running, label: "Mino", size: 66, accentColor: accentColor)

      Rectangle()
        .fill(Color.oeText)
        .frame(width: 2, height: 34)
        .rotationEffect(.degrees(46))
        .offset(x: 9, y: 2)

      ForEach(0..<4, id: \.self) { index in
        Image(systemName: "sparkle")
          .font(.system(size: index == 0 ? 10 : 7, weight: .bold))
          .foregroundColor(accentColor.color)
          .offset(x: CGFloat(index * 11 - 13), y: CGFloat(index.isMultiple(of: 2) ? -12 : 0))
      }
    }
  }
}

private struct NativeOnboardingContextTile: View {
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
    .frame(height: 76)
    .background(Color.oeBackground.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .nativeGlassStroke(cornerRadius: 18, color: Color.oeBorder.opacity(0.16))
  }
}

private struct NativeOnboardingProjectFolder: View {
  var accentColor: NativeAccentColor

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "folder.fill")
        .font(.system(size: 31, weight: .bold))
        .foregroundColor(accentColor.color)

      VStack(alignment: .leading, spacing: 4) {
        Text("Project Context")
          .font(.system(size: 16, weight: .heavy))
          .foregroundColor(.oeText)
        Text("One focused workspace")
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(.oeSecondaryText)
      }

      Spacer()
    }
    .padding(16)
    .background(Color.oeBackground.opacity(0.84), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .nativeGlassStroke(cornerRadius: 22, color: accentColor.color.opacity(0.16))
  }
}

private struct NativeOnboardingIslandPill: View {
  var body: some View {
    Capsule(style: .continuous)
      .fill(Color.oeText)
      .frame(width: 192, height: 54)
      .overlay {
        HStack(spacing: 12) {
          NativeDynamicIslandPetView(pet: .flux, motion: .running, size: 34)
            .frame(width: 42, height: 38)

          VStack(alignment: .leading, spacing: 4) {
            Text("Generating")
              .font(.system(size: 12, weight: .heavy))
              .foregroundColor(.white)
            Capsule(style: .continuous)
              .fill(Color.white.opacity(0.78))
              .frame(width: 82, height: 4)
          }

          NativeOnboardingSpinner()
            .frame(width: 18, height: 18)
        }
      }
  }
}

private struct NativeOnboardingChip: View {
  var title: String

  init(_ title: String) {
    self.title = title
  }

  var body: some View {
    Text(title)
      .font(.system(size: 9, weight: .black))
      .foregroundColor(.oeSecondaryText)
      .padding(.horizontal, 10)
      .frame(height: 26)
      .background(Color.oeBackground.opacity(0.76), in: Capsule(style: .continuous))
  }
}

private struct NativeOnboardingArrowLabel: View {
  var text: String

  var body: some View {
    Text(text)
      .font(.system(size: 12, weight: .heavy))
      .foregroundColor(.oeSecondaryText)
      .padding(.horizontal, 14)
      .frame(height: 34)
      .background(Color.oeBackground.opacity(0.72), in: Capsule(style: .continuous))
  }
}

private struct NativeOnboardingSoftBlob: View {
  var color: Color
  var alignment: Alignment

  var body: some View {
    Circle()
      .fill(color.opacity(0.12))
      .blur(radius: 32)
      .frame(width: 190, height: 190)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
      .padding(12)
  }
}

private struct NativeOnboardingSpinner: View {
  var body: some View {
    Circle()
      .trim(from: 0.08, to: 0.72)
      .stroke(.white.opacity(0.84), style: StrokeStyle(lineWidth: 3, lineCap: .round))
      .rotationEffect(.degrees(32))
  }
}
