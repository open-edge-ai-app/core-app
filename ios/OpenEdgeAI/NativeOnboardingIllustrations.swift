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
    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
      let motion = NativeOnboardingMotion(date: timeline.date)

      ZStack {
        NativeOnboardingSketchStage(accentColor: accentColor, motion: motion)

        switch scene {
        case .workspace:
          NativeOnboardingChatSketchScene(accentColor: accentColor, motion: motion)
        case .todo:
          NativeOnboardingTodoSketchScene(accentColor: accentColor, motion: motion)
        case .document:
          NativeOnboardingProjectSketchScene(accentColor: accentColor, motion: motion)
        case .progress:
          NativeOnboardingIslandSketchScene(accentColor: accentColor, motion: motion)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
  }
}

struct NativeOnboardingMotion {
  var date: Date

  private var time: TimeInterval {
    date.timeIntervalSinceReferenceDate
  }

  func wave(speed: Double = 0.55, offset: Double = 0) -> CGFloat {
    CGFloat(sin((time * speed + offset) * Double.pi * 2))
  }

  func float(_ amplitude: CGFloat, speed: Double = 0.55, offset: Double = 0) -> CGFloat {
    wave(speed: speed, offset: offset) * amplitude
  }

  func scale(_ amplitude: CGFloat = 0.03, speed: Double = 0.55, offset: Double = 0) -> CGFloat {
    1 + float(amplitude, speed: speed, offset: offset)
  }

  func progress(from start: CGFloat, to end: CGFloat, speed: Double = 0.55, offset: Double = 0) -> CGFloat {
    let normalized = (wave(speed: speed, offset: offset) + 1) / 2
    return start + (end - start) * normalized
  }

  func opacity(from start: Double, to end: Double, speed: Double = 0.55, offset: Double = 0) -> Double {
    let normalized = Double((wave(speed: speed, offset: offset) + 1) / 2)
    return start + (end - start) * normalized
  }

  func degrees(_ amplitude: Double, speed: Double = 0.55, offset: Double = 0) -> Double {
    Double(wave(speed: speed, offset: offset)) * amplitude
  }

  func rotation(speed: Double = 0.7, offset: Double = 0) -> Double {
    (time * speed + offset).truncatingRemainder(dividingBy: 1) * 360
  }
}

private struct NativeOnboardingChatSketchScene: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    ZStack {
      NativePixelTrail(color: accentColor.color, variant: 1, motion: motion)
        .frame(width: 206, height: 112)
        .offset(x: 26, y: -42)

      NativeSketchSceneBadge(icon: "bubble.left.and.text.bubble.right", title: "On-device answer", accentColor: accentColor)
        .offset(y: -124)
        .zIndex(2)

      VStack(spacing: 10) {
        NativePixelChatQuestion(accentColor: accentColor)
          .padding(.leading, 66)

        HStack(alignment: .top, spacing: 9) {
          NativeOnboardingPetActor(pet: .orbit, petMotion: .resting, size: 66)
            .rotationEffect(.degrees(motion.degrees(2.6, speed: 0.34)))
            .offset(x: motion.float(3, speed: 0.36), y: motion.float(6, speed: 0.42) + 22)

          NativePixelChatAnswer(accentColor: accentColor, motion: motion)
            .offset(x: motion.float(5, speed: 0.32, offset: 0.20))
        }
      }
      .padding(.horizontal, 22)
      .offset(y: 20)
    }
  }
}

private struct NativeOnboardingTodoSketchScene: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    ZStack {
      NativePixelTrail(color: accentColor.color, variant: 2, motion: motion)
        .frame(width: 230, height: 126)
        .offset(x: -6, y: 18)

      NativeSketchSceneBadge(icon: "checklist", title: "Chat to Todo", accentColor: accentColor)
        .offset(y: -124)
        .zIndex(2)

      HStack(alignment: .center, spacing: 14) {
        VStack(spacing: 12) {
          NativeSketchTaskRow(title: "VP meeting", time: "4:00 PM", isDone: true, accentColor: accentColor)
            .offset(x: motion.float(5, speed: 0.38, offset: 0.14), y: motion.float(3, speed: 0.48, offset: 0.28))
          NativeSketchTaskRow(title: "Send summary", time: "Today", isDone: false, accentColor: accentColor)
            .offset(x: motion.float(5, speed: 0.38, offset: 0.62), y: motion.float(3, speed: 0.48, offset: 0.76))
        }

        NativeOnboardingWandPet(accentColor: accentColor, motion: motion)
          .offset(y: motion.float(8, speed: 0.58))
      }
      .padding(.horizontal, 24)

      NativeSketchFlowCaption(text: "chat note  ->  scheduled task", accentColor: accentColor)
        .offset(y: 106)
        .opacity(motion.opacity(from: 0.58, to: 0.92, speed: 0.44))
    }
  }
}

private struct NativeOnboardingProjectSketchScene: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    ZStack {
      NativePixelTrail(color: Color.oeText, variant: 0, motion: motion)
        .frame(width: 246, height: 136)
        .offset(x: 4, y: -16)

      NativeSketchSceneBadge(icon: "folder", title: "Project context", accentColor: accentColor)
        .offset(y: -124)
        .zIndex(2)

      VStack(spacing: 14) {
        HStack(spacing: 12) {
          NativeSketchPaperNote(icon: "doc.text", title: "Brief")
            .offset(y: motion.float(6, speed: 0.36, offset: 0.08))
          NativeSketchPaperNote(icon: "paperclip", title: "Files")
            .offset(y: motion.float(6, speed: 0.36, offset: 0.42))
          NativeSketchPaperNote(icon: "message", title: "Chats")
            .offset(y: motion.float(6, speed: 0.36, offset: 0.74))
        }

        ZStack(alignment: .top) {
          NativeSketchFolder(accentColor: accentColor)
            .offset(y: 16)
            .scaleEffect(motion.scale(0.02, speed: 0.38, offset: 0.22))

          HStack(spacing: 26) {
            NativeOnboardingPetActor(pet: .luma, petMotion: .running, size: 58)
              .offset(x: motion.float(8, speed: 0.45, offset: 0.12), y: motion.float(5, speed: 0.42, offset: 0.32))
            NativeOnboardingPetActor(pet: .nullSignal, petMotion: .resting, size: 58)
              .offset(x: motion.float(6, speed: 0.40, offset: 0.70), y: motion.float(4, speed: 0.44, offset: 0.10))
          }
          .offset(y: -10)
        }
        .frame(height: 126)
      }
      .padding(.horizontal, 24)
    }
  }
}

private struct NativeOnboardingIslandSketchScene: View {
  var accentColor: NativeAccentColor
  var motion: NativeOnboardingMotion

  var body: some View {
    ZStack {
      NativePixelTrail(color: accentColor.color, variant: 3, motion: motion)
        .frame(width: 240, height: 138)
        .offset(y: 22)

      NativeSketchSceneBadge(icon: "waveform.path.ecg", title: "Live Activity", accentColor: accentColor)
        .offset(y: -136)
        .zIndex(2)

      VStack(spacing: 18) {
        NativeSketchIslandPill(accentColor: accentColor, motion: motion)
          .offset(y: motion.float(5, speed: 0.42, offset: 0.18))

        NativeSketchProgressPanel(accentColor: accentColor, motion: motion)

        NativeOnboardingPetActor(pet: .flux, petMotion: .running, size: 76)
          .rotationEffect(.degrees(motion.degrees(3, speed: 0.46, offset: 0.2)))
          .offset(y: motion.float(7, speed: 0.52, offset: 0.62))
      }
      .padding(.horizontal, 26)
      .offset(y: 10)
    }
  }
}
