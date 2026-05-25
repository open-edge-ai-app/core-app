import SwiftUI

struct NativeTodoLabelSelect: View {
  var i18n: NativeI18n
  var labels: [NativeTodoLabel]
  @Binding var selectedLabelId: String?
  var accentColor: Color

  private var selectedLabel: NativeTodoLabel? {
    labels.first { $0.id == selectedLabelId }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(i18n.t(.todoLabels))
        .font(.system(size: 13, weight: .bold))
        .foregroundColor(.oeMutedText)

      HStack(spacing: 12) {
        Image(systemName: "tag")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.oeMutedText)
          .frame(width: 22)

        Text(i18n.t(.todoLabels))
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.oeText)

        Spacer(minLength: 12)

        if labels.isEmpty {
          Text(i18n.t(.todoNoLabels))
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.oeMutedText)
        } else {
          if let selectedLabel {
            Circle()
              .fill(Color(todoLabelHex: selectedLabel.colorHex))
              .frame(width: 8, height: 8)
          }

          Picker(i18n.t(.todoLabels), selection: selectedBinding) {
            Text(i18n.t(.todoNoLabel)).tag("")
            ForEach(labels) { label in
              Text(label.title).tag(label.id)
            }
          }
          .pickerStyle(.menu)
          .tint(accentColor)
        }
      }
      .padding(.horizontal, 14)
      .frame(height: 54)
      .nativeLiquidGlass(cornerRadius: 14, interactive: true)
      .nativeGlassStroke(cornerRadius: 14, color: Color.oeBorder.opacity(0.28))
    }
  }

  private var selectedBinding: Binding<String> {
    Binding(
      get: { selectedLabelId ?? "" },
      set: { newValue in
        selectedLabelId = newValue.isEmpty ? nil : newValue
      }
    )
  }
}

struct NativeTodoDateTimeField: View {
  var title: String
  var systemImage: String
  @Binding var date: Date
  var tintColor: Color

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.oeMutedText)
        .frame(width: 22)

      Text(title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.oeText)

      Spacer(minLength: 12)

      DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
        .datePickerStyle(.compact)
        .labelsHidden()
        .tint(tintColor)
    }
    .padding(.horizontal, 14)
    .frame(height: 54)
    .nativeLiquidGlass(cornerRadius: 14, interactive: true)
    .nativeGlassStroke(cornerRadius: 14, color: Color.oeBorder.opacity(0.28))
  }
}

extension Color {
  init(todoLabelHex hex: String) {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var value: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&value)

    let red = Double((value >> 16) & 0xFF) / 255
    let green = Double((value >> 8) & 0xFF) / 255
    let blue = Double(value & 0xFF) / 255

    self.init(red: red, green: green, blue: blue)
  }
}
