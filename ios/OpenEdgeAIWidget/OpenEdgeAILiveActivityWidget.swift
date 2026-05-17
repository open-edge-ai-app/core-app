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
          OpenEdgeAIIslandPet(
            pet: context.state.pet,
            motion: context.state.motion,
            isEnabled: context.state.petEnabled,
            size: 34
          )
          .frame(width: 42, height: 38)
        }

        DynamicIslandExpandedRegion(.center) {
          VStack(alignment: .leading, spacing: 2) {
            Text(context.state.title)
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.white)
              .lineLimit(1)

            Text(context.state.subtitle)
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(.white.opacity(0.66))
              .lineLimit(1)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        DynamicIslandExpandedRegion(.trailing) {
          OpenEdgeAIQueueBadge(count: context.state.queuedCount)
        }

        DynamicIslandExpandedRegion(.bottom) {
          HStack(spacing: 6) {
            Circle()
              .fill(.white.opacity(context.state.motion == "running" ? 1 : 0.45))
              .frame(width: 6, height: 6)

            Text(context.state.motion == "running" ? "응답 생성 중" : "대기 중")
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(.white.opacity(0.7))
              .lineLimit(1)

            Spacer(minLength: 0)
          }
        }
      } compactLeading: {
        OpenEdgeAIIslandPet(
          pet: context.state.pet,
          motion: context.state.motion,
          isEnabled: context.state.petEnabled,
          size: 21
        )
        .frame(width: 24, height: 24)
      } compactTrailing: {
        Text(context.state.queuedCount > 0 ? "\(context.state.queuedCount)" : "AI")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 24, height: 24)
      } minimal: {
        OpenEdgeAIIslandPet(
          pet: context.state.pet,
          motion: context.state.motion,
          isEnabled: context.state.petEnabled,
          size: 17
        )
        .frame(width: 18, height: 18)
      }
    }
  }
}

private struct OpenEdgeAILockScreenActivityView: View {
  var state: OpenEdgeAIDynamicIslandAttributes.ContentState

  var body: some View {
    HStack(spacing: 12) {
      OpenEdgeAIIslandPet(
        pet: state.pet,
        motion: state.motion,
        isEnabled: state.petEnabled,
        size: 36
      )
      .frame(width: 44, height: 40)

      VStack(alignment: .leading, spacing: 3) {
        Text(state.title)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.white)
          .lineLimit(1)

        Text(state.subtitle)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.white.opacity(0.66))
          .lineLimit(1)
      }

      Spacer(minLength: 8)

      OpenEdgeAIQueueBadge(count: state.queuedCount)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }
}

private struct OpenEdgeAIQueueBadge: View {
  var count: Int

  var body: some View {
    Text(count > 0 ? "\(count)" : "ON")
      .font(.system(size: 11, weight: .bold))
      .foregroundStyle(.white)
      .frame(minWidth: 26, minHeight: 24)
      .padding(.horizontal, count > 0 ? 0 : 3)
      .background(.white.opacity(0.14), in: Capsule())
  }
}

private struct OpenEdgeAIIslandPet: View {
  var pet: String
  var motion: String
  var isEnabled: Bool
  var size: CGFloat

  private var pixelSize: CGFloat {
    size / 7
  }

  private var rows: [[Int]] {
    switch pet {
    case "stacky":
      return [
        [0, 0, 2, 2, 2, 0, 0],
        [0, 2, 3, 3, 3, 2, 0],
        [2, 3, 4, 3, 4, 3, 2],
        [2, 1, 1, 1, 1, 1, 2],
        [2, 3, 3, 3, 3, 3, 2],
        [0, 2, 1, 1, 1, 2, 0],
        [0, 2, 0, 0, 0, 2, 0]
      ]
    case "nullSignal":
      return [
        [0, 0, 2, 2, 2, 0, 0],
        [0, 2, 1, 1, 1, 2, 0],
        [2, 1, 4, 1, 4, 1, 2],
        [2, 1, 1, 2, 1, 1, 2],
        [2, 1, 3, 3, 3, 1, 2],
        [0, 2, 1, 1, 1, 2, 0],
        [0, 0, 2, 0, 2, 0, 0]
      ]
    default:
      return [
        [0, 0, 2, 2, 2, 0, 0],
        [0, 2, 1, 1, 1, 2, 0],
        [2, 1, 4, 1, 4, 1, 2],
        [2, 1, 1, 3, 1, 1, 2],
        [0, 2, 1, 1, 1, 2, 0],
        [0, 0, 2, 3, 2, 0, 0],
        [0, 2, 0, 0, 0, 2, 0]
      ]
    }
  }

  private var yOffset: CGFloat {
    switch motion {
    case "running":
      return -1.5
    case "sleeping":
      return 1.5
    default:
      return 0
    }
  }

  var body: some View {
    ZStack(alignment: .topTrailing) {
      if isEnabled {
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
      } else {
        Circle()
          .stroke(.white.opacity(0.22), lineWidth: 1)
          .frame(width: size * 0.72, height: size * 0.72)

        Circle()
          .fill(.white)
          .frame(width: size * 0.22, height: size * 0.22)
      }

      if motion == "sleeping", isEnabled {
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
      return pet == "nullSignal" ? .black.opacity(0.82) : .white
    case 2:
      return pet == "nullSignal" ? .white.opacity(0.9) : .black
    case 3:
      return pet == "stacky" ? .white : .white.opacity(0.52)
    case 4:
      return pet == "nullSignal" ? .white : .black
    default:
      return .clear
    }
  }
}
