import SwiftUI

struct NativeProjectComposerBar: View {
  var project: NativeProject
  @Binding var showingAttachmentOptions: Bool

  var body: some View {
    NativeChatComposerBar(
      project: project,
      showingAttachmentOptions: $showingAttachmentOptions
    )
  }
}
