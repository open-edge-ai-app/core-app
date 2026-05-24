import Foundation
import SwiftUI
import UIKit

struct NativeMarkdownCodeBlock: View {
  @EnvironmentObject private var store: NativeChatStore
  let language: String?
  let code: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        if let language, !language.isEmpty {
          Text(language.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.oeMutedText)
        }

        Spacer(minLength: 8)

        Button {
          store.copy(code)
        } label: {
          Image(systemName: "doc.on.doc")
            .font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(.plain)
        .foregroundColor(store.accentColor.color)
        .accessibilityLabel(store.i18n.t(.chatCopyCode))
      }

      ScrollView(.horizontal, showsIndicators: false) {
        Text(code)
          .font(.system(size: max(12, store.fontSizeSetting.bodySize - 1), design: .monospaced))
          .foregroundColor(.oeText)
          .textSelection(.enabled)
          .fixedSize(horizontal: true, vertical: false)
          .padding(.bottom, 2)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .nativeLiquidGlass(cornerRadius: 12)
    .nativeGlassStroke(cornerRadius: 12)
  }
}
