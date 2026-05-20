import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Photos
import PhotosUI

struct NativeRootView: View {
  @EnvironmentObject private var store: NativeChatStore
  @State private var showingSessions = false
  @State private var showingSettings = false
  @State private var showingAttachmentOptions = false
  @State private var showingFileImporter = false
  @State private var showingPhotoPicker = false
  @State private var showingPhotoPermissionAlert = false
  @State private var selectedPhotoItems: [PhotosPickerItem] = []

  var body: some View {
    ZStack(alignment: .leading) {
      VStack(spacing: 0) {
        NativeTopBar(
          showingSessions: $showingSessions
        )
        .zIndex(2)

        Divider()
        NativeChatTranscript()
        NativeInputBar(showingAttachmentOptions: $showingAttachmentOptions)
      }
      .background(Color.oeBackground)

      if showingSessions {
        NativeSessionsView(
          isPresented: $showingSessions,
          showingSettings: $showingSettings,
          showingAttachmentOptions: $showingAttachmentOptions
        )
          .environmentObject(store)
          .transition(.move(edge: .leading))
          .zIndex(4)
      }
    }
    .animation(.easeOut(duration: 0.24), value: showingSessions)
    .sheet(isPresented: $showingSettings) {
      NativeSettingsView()
        .environmentObject(store)
    }
    .confirmationDialog(store.i18n.t(.attachmentAdd), isPresented: $showingAttachmentOptions, titleVisibility: .visible) {
      Button {
        requestPhotoLibraryAccess()
      } label: {
        Label(store.i18n.t(.attachmentPhotoOrVideo), systemImage: "photo.on.rectangle")
      }

      Button {
        showingFileImporter = true
      } label: {
        Label(store.i18n.t(.attachmentFile), systemImage: "doc")
      }

      Button(store.i18n.t(.commonCancel), role: .cancel) {}
    } message: {
      Text(store.i18n.t(.attachmentDialogMessage))
    }
    .photosPicker(
      isPresented: $showingPhotoPicker,
      selection: $selectedPhotoItems,
      maxSelectionCount: 12,
      matching: .any(of: [.images, .videos])
    )
    .onChange(of: selectedPhotoItems) { _, items in
      guard !items.isEmpty else {
        return
      }

      Task {
        await store.addPhotoAttachments(from: items)
        await MainActor.run {
          selectedPhotoItems = []
        }
      }
    }
    .alert(store.i18n.t(.attachmentPhotoPermissionTitle), isPresented: $showingPhotoPermissionAlert) {
      Button(store.i18n.t(.commonOk), role: .cancel) {}
      Button(store.i18n.t(.commonOpenSettings)) {
        openAppSettings()
      }
    } message: {
      Text(store.i18n.t(.attachmentPhotoPermissionMessage))
    }
    .fileImporter(
      isPresented: $showingFileImporter,
      allowedContentTypes: [.item],
      allowsMultipleSelection: true
    ) { result in
      if case .success(let urls) = result {
        store.addAttachments(from: urls)
      }
    }
    .task {
      await store.pollModelStatuses()
    }
  }

  private func requestPhotoLibraryAccess() {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    switch status {
    case .authorized, .limited:
      showingPhotoPicker = true
    case .notDetermined:
      PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
        DispatchQueue.main.async {
          if newStatus == .authorized || newStatus == .limited {
            showingPhotoPicker = true
          } else {
            showingPhotoPermissionAlert = true
          }
        }
      }
    case .denied, .restricted:
      showingPhotoPermissionAlert = true
    @unknown default:
      showingPhotoPicker = true
    }
  }

  private func openAppSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      return
    }
    UIApplication.shared.open(url)
  }
}
