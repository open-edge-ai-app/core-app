import SwiftUI

struct NativeProjectComposerBar: View {
  var project: NativeProject
  @Binding var showingAttachmentOptions: Bool
  var onPickPhotoOrVideo: () -> Void
  var onPickFile: () -> Void

  var body: some View {
    NativeChatComposerBar(
      project: project,
      showingAttachmentOptions: $showingAttachmentOptions,
      onPickPhotoOrVideo: onPickPhotoOrVideo,
      onPickFile: onPickFile
    )
  }
}
