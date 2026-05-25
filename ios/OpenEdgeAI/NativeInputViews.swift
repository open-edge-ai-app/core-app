import SwiftUI

struct NativeInputBar: View {
  @Binding var showingAttachmentOptions: Bool
  var onPickPhotoOrVideo: () -> Void
  var onPickFile: () -> Void

  var body: some View {
    NativeChatComposerBar(
      project: nil,
      showingAttachmentOptions: $showingAttachmentOptions,
      onPickPhotoOrVideo: onPickPhotoOrVideo,
      onPickFile: onPickFile
    )
  }
}
