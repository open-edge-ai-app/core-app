import SwiftUI

enum NativeOnboardingScene {
  case privacy
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
        case .privacy:
          NativeOnboardingChatSketchScene(accentColor: accentColor, motion: motion)
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
