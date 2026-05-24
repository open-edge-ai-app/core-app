import SwiftUI

struct NativeInputBar: View {
  @Binding var showingAttachmentOptions: Bool

  var body: some View {
    NativeChatComposerBar(
      project: nil,
      showingAttachmentOptions: $showingAttachmentOptions
    )
  }
}
