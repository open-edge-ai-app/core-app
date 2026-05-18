import SwiftUI

@main
struct OpenEdgeAIApp: App {
  @StateObject private var store = NativeChatStore()

  var body: some Scene {
    WindowGroup {
      NativeRootView()
        .environmentObject(store)
        .preferredColorScheme(store.appearanceMode.colorScheme)
        .tint(store.accentColor.color)
    }
  }
}
