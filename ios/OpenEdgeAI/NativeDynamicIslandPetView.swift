import SwiftUI

struct NativeDynamicIslandPetView: View {
  var pet: NativeDynamicIslandPet
  var motion: NativeDynamicIslandPetMotion
  var size: CGFloat
  @State private var phase = false

  private var rows: [[Int]] {
    NativeDynamicIslandPetSprite.rows(for: pet.rawValue)
  }

  private var pixelSize: CGFloat {
    size / CGFloat(NativeDynamicIslandPetSprite.dimension)
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
              .frame(width: 2.8, height: phase == (index == 1) ? 6 : 3.5)
          }
        }
        .offset(x: 8, y: -8)
        .opacity(phase ? 1 : 0.62)
        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: phase)
      }

      if motion == .sleeping {
        Text("Z")
          .font(.system(size: 9, weight: .black, design: .monospaced))
          .foregroundColor(Color(uiColor: .white).opacity(0.78))
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
    case 5:
      return pet.cheekColor
    case 6:
      return pet.sparkleColor
    case 7:
      return pet.skinColor
    case 8:
      return pet.hairColor
    default:
      return Color.clear
    }
  }
}
