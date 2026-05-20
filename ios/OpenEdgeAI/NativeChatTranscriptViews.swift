import SwiftUI

struct NativeChatTranscript: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 18) {
          if store.currentMessages.isEmpty {
            NativeEmptyChatView()
              .padding(.top, 80)
          } else {
            ForEach(store.currentMessages) { message in
              NativeMessageView(message: message)
                .id(message.id)
            }
          }

          Color.clear
            .frame(height: 1)
            .id("bottom")
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 24)
      }
      .background(Color.oeBackground)
      .onChange(of: store.currentMessages) { _, _ in
        withAnimation(.easeOut(duration: 0.2)) {
          proxy.scrollTo("bottom", anchor: .bottom)
        }
      }
    }
  }
}
