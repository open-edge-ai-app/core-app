import UIKit

@MainActor
extension NativeChatStore {
  var canRunBackgroundDynamicIsland: Bool {
    backgroundExecutionEnabled && backgroundDynamicIslandEnabled
  }

  var canRunDynamicIslandPet: Bool {
    canRunBackgroundDynamicIsland && dynamicIslandPetEnabled
  }

  var dynamicIslandState: NativeDynamicIslandState {
    let phase = dynamicIslandPhase
    guard phase != .hidden else {
      return .hidden
    }

    return NativeDynamicIslandState(
      phase: phase,
      title: dynamicIslandTitle(for: phase),
      subtitle: dynamicIslandSubtitle(for: phase),
      detail: dynamicIslandDetail(for: phase),
      progress: dynamicIslandProgress(for: phase),
      motion: dynamicIslandPetMotion(for: phase),
      pet: selectedDynamicIslandPet,
      isPetEnabled: canRunDynamicIslandPet,
      queuedCount: queuedDrafts.count,
      isGenerating: isGenerating
    )
  }

  var showsSystemDynamicIslandActivity: Bool {
    canRunBackgroundDynamicIsland && dynamicIslandState.isVisible
  }

  private var dynamicIslandPhase: NativeDynamicIslandPhase {
    if isGenerating {
      return .generating
    }
    if !queuedDrafts.isEmpty {
      return .queued
    }
    return .hidden
  }

  private func dynamicIslandTitle(for phase: NativeDynamicIslandPhase) -> String {
    switch phase {
    case .generating:
      return queuedDrafts.isEmpty ? "응답 생성 중" : "후속 질문 실행 중"
    case .queued:
      return "후속 질문 대기 중"
    case .hidden:
      return ""
    }
  }

  private func dynamicIslandSubtitle(for phase: NativeDynamicIslandPhase) -> String {
    if queuedDrafts.first != nil {
      return "다음 작업 준비 중"
    }

    switch phase {
    case .generating, .queued:
      return selectedModel.title
    case .hidden:
      return ""
    }
  }

  private func dynamicIslandDetail(for phase: NativeDynamicIslandPhase) -> String {
    switch phase {
    case .generating:
      if queuedDrafts.isEmpty {
        return "\(selectedModel.title)로 응답을 생성하고 있습니다."
      }
      return "현재 응답 후 후속 질문 \(queuedDrafts.count)개를 이어서 실행합니다."
    case .queued:
      return "후속 질문 \(queuedDrafts.count)개가 대기 중입니다."
    case .hidden:
      return ""
    }
  }

  private func dynamicIslandProgress(for phase: NativeDynamicIslandPhase) -> Double {
    switch phase {
    case .generating:
      return queuedDrafts.isEmpty ? 0.64 : 0.72
    case .queued:
      return 0.28
    case .hidden:
      return 0
    }
  }

  private func dynamicIslandPetMotion(for phase: NativeDynamicIslandPhase) -> NativeDynamicIslandPetMotion {
    switch phase {
    case .generating:
      return .running
    case .queued, .hidden:
      return .resting
    }
  }

  func dismissDynamicIslandActivity() {
    syncDynamicIslandLiveActivity()
  }

  func refreshDynamicIslandActivity() {
    syncDynamicIslandLiveActivity()
  }

  func refreshBackgroundExecutionState() {
    if backgroundExecutionEnabled, isGenerating {
      beginGenerationBackgroundTaskIfNeeded()
    } else {
      endGenerationBackgroundTaskIfNeeded()
    }

    if !backgroundExecutionEnabled {
      syncDynamicIslandLiveActivity()
    } else if backgroundDynamicIslandEnabled {
      refreshDynamicIslandActivity()
    }
  }

  func showDynamicIslandWork() {
    syncDynamicIslandLiveActivity()
  }

  func syncDynamicIslandLiveActivity() {
    let state = dynamicIslandState
    NativeDynamicIslandLiveActivityController.shared.sync(
      enabled: canRunBackgroundDynamicIsland,
      isVisible: showsSystemDynamicIslandActivity,
      sessionId: dynamicIslandActivityId,
      title: state.title,
      subtitle: state.subtitle,
      pet: state.pet.rawValue,
      petEnabled: state.isPetEnabled,
      motion: state.motion.rawValue,
      queuedCount: state.queuedCount,
      progress: state.progress,
      detail: state.detail
    )
  }

  func beginGenerationBackgroundTaskIfNeeded() {
    guard backgroundExecutionEnabled,
          generationBackgroundTaskIdentifier == .invalid
    else {
      return
    }

    generationBackgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(
      withName: "OpenEdgeAI.Generation"
    ) { [weak self] in
      Task { @MainActor in
        self?.endGenerationBackgroundTaskIfNeeded()
      }
    }
  }

  func endGenerationBackgroundTaskIfNeeded() {
    guard generationBackgroundTaskIdentifier != .invalid else {
      return
    }

    let identifier = generationBackgroundTaskIdentifier
    generationBackgroundTaskIdentifier = .invalid
    UIApplication.shared.endBackgroundTask(identifier)
  }
}
