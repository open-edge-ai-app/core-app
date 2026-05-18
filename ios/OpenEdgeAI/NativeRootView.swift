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
    .confirmationDialog("첨부 추가", isPresented: $showingAttachmentOptions, titleVisibility: .visible) {
      Button {
        requestPhotoLibraryAccess()
      } label: {
        Label("사진 또는 동영상", systemImage: "photo.on.rectangle")
      }

      Button {
        showingFileImporter = true
      } label: {
        Label("파일", systemImage: "doc")
      }

      Button("취소", role: .cancel) {}
    } message: {
      Text("이미지, 동영상, 문서 파일을 대화에 첨부할 수 있습니다.")
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
    .alert("사진 접근 권한 필요", isPresented: $showingPhotoPermissionAlert) {
      Button("확인", role: .cancel) {}
      Button("설정 열기") {
        openAppSettings()
      }
    } message: {
      Text("사진과 동영상을 첨부하려면 사진 보관함 접근 권한을 허용해 주세요.")
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
