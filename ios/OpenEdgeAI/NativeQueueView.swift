import SwiftUI

struct NativeQueueView: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    VStack(spacing: 6) {
      ForEach(store.queuedDrafts) { draft in
        HStack(spacing: 8) {
          TextField(store.i18n.t(.chatQueuedFollowUp), text: Binding(
            get: { draft.text },
            set: { store.updateQueuedDraft(draft, text: $0) }
          ))
          .font(.system(size: 13))

          Button {
            store.removeQueuedDraft(draft)
          } label: {
            Image(systemName: "xmark")
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(store.accentColor.subtleColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
    }
  }
}
