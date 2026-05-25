import ActivityKit
import SwiftUI
import WidgetKit

struct OpenEdgeAILiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: OpenEdgeAIDynamicIslandAttributes.self) { context in
      OpenEdgeAILockScreenActivityView(state: context.state)
        .activityBackgroundTint(.black)
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          OpenEdgeAIIslandIdentity(state: context.state, size: 48)
            .frame(width: 58, height: 54)
        }

        DynamicIslandExpandedRegion(.trailing) {
          OpenEdgeAIIslandProgressRing(
            progress: context.state.progress,
            isActive: context.state.motion == "running",
            size: 42,
            lineWidth: 4
          )
          .frame(width: 58, height: 54)
        }

        DynamicIslandExpandedRegion(.center) {
          VStack(alignment: .leading, spacing: 3) {
            Text(context.state.title)
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.white)
              .lineLimit(1)
              .minimumScaleFactor(0.82)

            Text(context.state.subtitle)
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(.white.opacity(0.66))
              .lineLimit(1)
              .minimumScaleFactor(0.78)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 7) {
            OpenEdgeAIActivityDetailRow(
              icon: context.state.motion == "running" ? "gearshape.fill" : "clock",
              text: context.state.detail
            )

            if context.state.queuedCount > 0 {
              OpenEdgeAIActivityDetailRow(
                icon: "text.line.first.and.arrowtriangle.forward",
                text: "대기열 \(context.state.queuedCount)개가 다음 작업으로 준비되어 있습니다."
              )
            }
          }
          .padding(.top, 2)
        }
      } compactLeading: {
        OpenEdgeAIIslandIdentity(state: context.state, size: 22)
          .frame(width: 24, height: 24)
      } compactTrailing: {
        OpenEdgeAIIslandProgressRing(
          progress: context.state.progress,
          isActive: context.state.motion == "running",
          size: 22,
          lineWidth: 2.6
        )
        .frame(width: 24, height: 24)
      } minimal: {
        OpenEdgeAIIslandProgressRing(
          progress: context.state.progress,
          isActive: context.state.motion == "running",
          size: 18,
          lineWidth: 2.2
        )
        .frame(width: 18, height: 18)
      }
    }
  }
}

private struct OpenEdgeAILockScreenActivityView: View {
  var state: OpenEdgeAIDynamicIslandAttributes.ContentState

  var body: some View {
    HStack(spacing: 13) {
      OpenEdgeAIIslandIdentity(state: state, size: 40)
        .frame(width: 48, height: 46)

      VStack(alignment: .leading, spacing: 4) {
        Text(state.title)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.white)
          .lineLimit(1)

        Text(state.detail)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.white.opacity(0.66))
          .lineLimit(2)
      }

      Spacer(minLength: 8)

      OpenEdgeAIIslandProgressRing(
        progress: state.progress,
        isActive: state.motion == "running",
        size: 34,
        lineWidth: 3.5
      )
      .frame(width: 38, height: 38)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }
}

private struct OpenEdgeAIActivityDetailRow: View {
  var icon: String
  var text: String

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: icon)
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.white.opacity(0.78))
        .frame(width: 13)

      Text(text)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.white.opacity(0.72))
        .lineLimit(2)
        .minimumScaleFactor(0.8)

      Spacer(minLength: 0)
    }
  }
}

private struct OpenEdgeAIIslandIdentity: View {
  var state: OpenEdgeAIDynamicIslandAttributes.ContentState
  var size: CGFloat

  var body: some View {
    if state.petEnabled {
      OpenEdgeAIIslandPet(
        pet: state.pet,
        motion: state.motion,
        size: size
      )
    } else {
      OpenEdgeAILiveMark(size: size)
    }
  }
}

private struct OpenEdgeAIIslandProgressRing: View {
  var progress: Double
  var isActive: Bool
  var size: CGFloat
  var lineWidth: CGFloat

  private var clampedProgress: Double {
    min(max(progress, 0.08), 1)
  }

  var body: some View {
    ZStack {
      Circle()
        .stroke(.white.opacity(0.18), lineWidth: lineWidth)

      if isActive {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
          Circle()
            .trim(from: 0.05, to: 0.34)
            .stroke(
              .white,
              style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(spinnerRotation(at: timeline.date))
        }
      } else {
        Circle()
          .trim(from: 0, to: clampedProgress)
          .stroke(
            .white.opacity(0.78),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
      }
    }
    .frame(width: size, height: size)
  }

  private func spinnerRotation(at date: Date) -> Angle {
    let duration = 0.82
    let elapsed = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration)
    return .degrees((elapsed / duration) * 360 - 90)
  }
}

private struct OpenEdgeAILiveMark: View {
  var size: CGFloat

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        .stroke(.white.opacity(0.86), lineWidth: max(1.2, size * 0.07))
        .rotationEffect(.degrees(-14))

      Text("OE")
        .font(.system(size: size * 0.34, weight: .black, design: .rounded))
        .foregroundStyle(.white)
    }
    .frame(width: size, height: size)
  }
}

private struct OpenEdgeAIIslandPet: View {
  var pet: String
  var motion: String
  var size: CGFloat

  private var pixelSize: CGFloat {
    size / CGFloat(NativeDynamicIslandPetSprite.dimension)
  }

  private var rows: [[Int]] {
    NativeDynamicIslandPetSprite.rows(for: pet)
  }

  private var yOffset: CGFloat {
    switch motion {
    case "running":
      return -0.7
    case "sleeping":
      return 0.8
    default:
      return 0
    }
  }

  var body: some View {
    ZStack(alignment: .topTrailing) {
      VStack(spacing: 0) {
        ForEach(rows.indices, id: \.self) { rowIndex in
          HStack(spacing: 0) {
            ForEach(rows[rowIndex].indices, id: \.self) { columnIndex in
              Rectangle()
                .fill(color(for: rows[rowIndex][columnIndex]))
                .frame(width: pixelSize, height: pixelSize)
            }
          }
        }
      }
      .frame(width: size, height: size)
      .offset(y: yOffset)

      if motion == "running" {
        HStack(spacing: max(1, size * 0.05)) {
          ForEach(0..<3, id: \.self) { index in
            RoundedRectangle(cornerRadius: max(1, size * 0.04), style: .continuous)
              .fill(secondaryColor.opacity(index == 1 ? 0.9 : 0.64))
              .frame(width: max(2, size * 0.08), height: index == 1 ? max(5, size * 0.18) : max(3, size * 0.11))
          }
        }
        .offset(x: size * 0.2, y: -size * 0.2)
      }

      if motion == "sleeping" {
        Text("Z")
          .font(.system(size: max(7, size * 0.28), weight: .black, design: .monospaced))
          .foregroundStyle(.white.opacity(0.76))
          .offset(x: size * 0.18, y: -size * 0.14)
      }
    }
    .frame(width: size + 6, height: size + 6)
  }

  private func color(for value: Int) -> Color {
    switch value {
    case 1:
      return primaryColor
    case 2:
      return outlineColor
    case 3:
      return secondaryColor
    case 4:
      return eyeColor
    case 5:
      return cheekColor
    case 6:
      return sparkleColor
    case 7:
      return skinColor
    case 8:
      return hairColor
    default:
      return .clear
    }
  }

  private var primaryColor: Color {
    NativeDynamicIslandPetSprite.primaryColor(for: pet)
  }

  private var secondaryColor: Color {
    NativeDynamicIslandPetSprite.secondaryColor(for: pet)
  }

  private var outlineColor: Color {
    NativeDynamicIslandPetSprite.outlineColor(for: pet)
  }

  private var eyeColor: Color {
    NativeDynamicIslandPetSprite.eyeColor(for: pet)
  }

  private var cheekColor: Color {
    NativeDynamicIslandPetSprite.cheekColor(for: pet)
  }

  private var sparkleColor: Color {
    NativeDynamicIslandPetSprite.sparkleColor(for: pet)
  }

  private var skinColor: Color {
    NativeDynamicIslandPetSprite.skinColor(for: pet)
  }

  private var hairColor: Color {
    NativeDynamicIslandPetSprite.hairColor(for: pet)
  }
}
