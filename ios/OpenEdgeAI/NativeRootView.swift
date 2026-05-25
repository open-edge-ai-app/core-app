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
      ZStack(alignment: .bottom) {
        NativeChatTranscript(
          topPadding: nativeTopBarTranscriptPadding,
          bottomPadding: nativeComposerScrollBottomPadding
        )

        NativeRootBottomTranscriptFade()
          .zIndex(1)

        NativeInputBar(
          showingAttachmentOptions: $showingAttachmentOptions,
          onPickPhotoOrVideo: requestPhotoLibraryAccess,
          onPickFile: openFileImporter
        )
          .zIndex(2)
          .ignoresSafeArea(.container, edges: .bottom)
      }
      .overlay(alignment: .top) {
        NativeTopBar(
          showingSessions: $showingSessions
        )
        .zIndex(2)
      }
      .background(Color.oeBackground)

      if showingSessions {
        NativeSessionsView(
          isPresented: $showingSessions,
          showingSettings: $showingSettings,
          showingAttachmentOptions: $showingAttachmentOptions,
          onPickPhotoOrVideo: requestPhotoLibraryAccess,
          onPickFile: openFileImporter
        )
          .environmentObject(store)
          .transition(.move(edge: .leading))
          .zIndex(4)
      }
    }
    .overlay {
      if !store.hasCompletedOnboarding {
        NativeOnboardingView {
          store.completeOnboarding()
        }
        .environmentObject(store)
        .transition(.opacity)
        .zIndex(20)
      }
    }
    .animation(.easeOut(duration: 0.24), value: showingSessions)
    .animation(.easeInOut(duration: 0.24), value: store.hasCompletedOnboarding)
    .sheet(isPresented: $showingSettings) {
      NativeSettingsView()
        .environmentObject(store)
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

  private func openFileImporter() {
    showingFileImporter = true
  }

  private func openAppSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      return
    }
    UIApplication.shared.open(url)
  }
}

private struct NativeRootBottomTranscriptFade: View {
  var body: some View {
    GeometryReader { proxy in
      VStack(spacing: 0) {
        Spacer(minLength: 0)

        NativeChatTranscriptEdgeFade(
          edge: .bottom,
          height: 226 + proxy.safeAreaInsets.bottom
        )
        .frame(maxWidth: .infinity)
        .offset(y: proxy.safeAreaInsets.bottom)
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .ignoresSafeArea(.container, edges: .bottom)
    .allowsHitTesting(false)
  }
}
