import SwiftUI

struct NativeTopBar: View {
  @EnvironmentObject private var store: NativeChatStore
  @Binding var showingSessions: Bool

  var body: some View {
    NativeGlassEffectContainer(spacing: 12) {
      HStack(spacing: 12) {
        Button {
          withAnimation(.easeOut(duration: 0.24)) {
            showingSessions = true
          }
        } label: {
          NativeTopBarGlassCircle {
            Image(systemName: "line.3.horizontal")
              .font(.system(size: 18, weight: .semibold))
          }
        }
        .accessibilityLabel(store.i18n.t(.chatOpenList))
        .buttonStyle(.plain)

        Button {
          store.createNewSession()
        } label: {
          NativeTopBarGlassCapsule {
            Text(store.currentSession?.title ?? "Open Edge AI")
              .font(.system(size: 15, weight: .semibold))
              .lineLimit(1)
              .frame(maxWidth: 132, alignment: .leading)
          }
        }
        .buttonStyle(.plain)
        .layoutPriority(1)

        Spacer(minLength: 8)

        NativeModelMenu()
      }
    }
    .foregroundColor(.oeText)
    .padding(.horizontal, 16)
    .padding(.top, 6)
    .padding(.bottom, 8)
  }
}

struct NativeModelMenu: View {
  @EnvironmentObject private var store: NativeChatStore

  var body: some View {
    Menu {
      ForEach(NativeModel.allCases) { model in
        let status = store.modelStatuses[model] ?? NativeModelStatus(model: model)
        Button {
          store.selectedModel = model
          store.saveSettings()
          if status.installed || status.systemManaged {
            store.loadSelectedModel()
          }
        } label: {
          Label(model.title, systemImage: store.selectedModel == model ? "checkmark" : "")
        }

        if model == .gemma && !status.installed {
          Button {
            store.downloadGemma()
          } label: {
            Label(
              status.downloading ? store.i18n.t(.commonDownloading) : store.i18n.t(.commonDownload),
              systemImage: status.downloading ? "arrow.triangle.2.circlepath" : "arrow.down.circle"
            )
          }
        }
      }
    } label: {
      NativeTopBarGlassCapsule {
        HStack(spacing: 6) {
          Text(store.selectedModel.title)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
          Image(systemName: "chevron.down")
            .font(.system(size: 10, weight: .bold))
        }
        .frame(minWidth: 72)
      }
      .foregroundColor(.oeText)
    }
  }
}

private struct NativeTopBarGlassCircle<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme
  @ViewBuilder var content: Content

  var body: some View {
    content
      .foregroundColor(.oeText)
      .frame(width: 38, height: 38)
      .background(glassFill)
      .modifier(NativeTopBarCircleGlassEffect(tint: glassTint))
      .overlay(circleBorder)
  }

  private var glassFill: some View {
    Circle()
      .fill(.ultraThinMaterial)
      .overlay {
        Circle()
          .fill(glassTint)
      }
  }

  private var glassTint: Color {
    colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.68)
  }

  private var circleBorder: some View {
    Circle()
      .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 0.7)
      .allowsHitTesting(false)
  }
}

private struct NativeTopBarGlassCapsule<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme
  @ViewBuilder var content: Content

  var body: some View {
    content
      .foregroundColor(.oeText)
      .padding(.horizontal, 12)
      .frame(height: 36)
      .background(glassFill)
      .modifier(NativeTopBarCapsuleGlassEffect(tint: glassTint))
      .overlay(capsuleBorder)
  }

  private var glassFill: some View {
    Capsule(style: .continuous)
      .fill(.ultraThinMaterial)
      .overlay {
        Capsule(style: .continuous)
          .fill(glassTint)
      }
  }

  private var glassTint: Color {
    colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.64)
  }

  private var capsuleBorder: some View {
    Capsule(style: .continuous)
      .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 0.7)
      .allowsHitTesting(false)
  }
}

private struct NativeTopBarCircleGlassEffect: ViewModifier {
  var tint: Color

  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content.glassEffect(.regular.tint(tint).interactive(), in: .circle)
    } else {
      content
    }
  }
}

private struct NativeTopBarCapsuleGlassEffect: ViewModifier {
  var tint: Color

  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
    } else {
      content
    }
  }
}
