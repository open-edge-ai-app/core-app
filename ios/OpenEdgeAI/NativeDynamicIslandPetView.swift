import SwiftUI

struct NativeDynamicIslandPetView: View {
  var pet: NativeDynamicIslandPet
  var motion: NativeDynamicIslandPetMotion
  var size: CGFloat
  @State private var phase = false

  private var rows: [[Int]] {
    switch pet {
    case .orbit:
      return [
        [0, 0, 2, 2, 2, 0, 0],
        [0, 2, 1, 1, 1, 2, 0],
        [2, 1, 4, 1, 4, 1, 2],
        [2, 1, 1, 3, 1, 1, 2],
        [0, 2, 1, 1, 1, 2, 0],
        [0, 3, 2, 1, 2, 3, 0],
        [3, 0, 2, 0, 2, 0, 3]
      ]
    case .stacky:
      return [
        [0, 0, 2, 2, 2, 0, 0],
        [0, 2, 3, 3, 3, 2, 0],
        [2, 3, 4, 3, 4, 3, 2],
        [2, 1, 1, 1, 1, 1, 2],
        [2, 3, 3, 3, 3, 3, 2],
        [0, 2, 1, 1, 1, 2, 0],
        [3, 2, 0, 0, 0, 2, 3]
      ]
    case .nullSignal:
      return [
        [0, 0, 2, 2, 2, 0, 0],
        [0, 2, 1, 1, 1, 2, 0],
        [2, 1, 4, 1, 4, 1, 2],
        [2, 1, 1, 2, 1, 1, 2],
        [2, 1, 3, 3, 3, 1, 2],
        [0, 2, 1, 1, 1, 2, 0],
        [0, 0, 2, 0, 2, 0, 0]
      ]
    case .luma:
      return [
        [0, 0, 3, 3, 3, 0, 0],
        [0, 3, 1, 1, 1, 3, 0],
        [3, 1, 4, 1, 4, 1, 3],
        [2, 1, 1, 1, 1, 1, 2],
        [0, 3, 1, 2, 1, 3, 0],
        [0, 0, 3, 1, 3, 0, 0],
        [0, 3, 0, 0, 0, 3, 0]
      ]
    case .flux:
      return [
        [0, 0, 3, 1, 3, 0, 0],
        [0, 3, 1, 1, 1, 3, 0],
        [3, 1, 4, 1, 4, 1, 3],
        [2, 1, 1, 3, 1, 1, 2],
        [0, 3, 1, 1, 1, 3, 0],
        [0, 0, 2, 3, 2, 0, 0],
        [0, 2, 0, 0, 0, 2, 0]
      ]
    }
  }

  private var pixelSize: CGFloat {
    size / 7
  }

  private var bodyOffset: CGFloat {
    switch motion {
    case .running:
      return phase ? -1.1 : 0.7
    case .resting:
      return phase ? -0.4 : 0.4
    case .sleeping:
      return 0.6
    }
  }

  private var tilt: Double {
    switch motion {
    case .running:
      return phase ? -2.5 : 2.5
    case .resting:
      return phase ? -0.8 : 0.8
    case .sleeping:
      return -2
    }
  }

  private var animationDuration: Double {
    switch motion {
    case .running:
      return 0.58
    case .resting:
      return 1.35
    case .sleeping:
      return 1
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
      .offset(y: bodyOffset)
      .rotationEffect(.degrees(tilt))
      .animation(.easeInOut(duration: animationDuration).repeatForever(autoreverses: true), value: phase)

      if motion == .running {
        HStack(spacing: 2) {
          ForEach(0..<3, id: \.self) { index in
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
              .fill(pet.secondaryColor.opacity(index == 1 ? 0.9 : 0.64))
              .frame(width: 3.5, height: phase == (index == 1) ? 7 : 4)
          }
        }
        .offset(x: 8, y: -8)
        .opacity(phase ? 1 : 0.62)
        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: phase)
      }

      if motion == .sleeping {
        Text("Z")
          .font(.system(size: 9, weight: .black, design: .monospaced))
          .foregroundColor(.white.opacity(0.78))
          .offset(x: 7, y: -6)
      }
    }
    .frame(width: size + 8, height: size + 6)
    .onAppear {
      phase = true
    }
    .onChange(of: motion) { _, _ in
      phase.toggle()
    }
    .accessibilityHidden(true)
  }

  private func color(for value: Int) -> Color {
    switch value {
    case 1:
      return pet.primaryColor
    case 2:
      return pet.outlineColor
    case 3:
      return pet.secondaryColor
    case 4:
      return pet.eyeColor
    default:
      return Color.clear
    }
  }
}
