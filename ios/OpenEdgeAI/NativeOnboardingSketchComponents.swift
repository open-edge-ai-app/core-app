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
                x: CGFloat(column) * proxy.size.width / 10 - proxy.size.width / 2,
                y: CGFloat(row) * proxy.size.height / 7 - proxy.size.height / 2
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
