import Foundation

struct NativeChatSession: Identifiable, Codable, Equatable {
  var id: String
  var title: String
  var projectId: String?
  var createdAt: Date
  var updatedAt: Date
  var messages: [NativeMessage]
}

struct NativeProject: Identifiable, Codable, Hashable {
  var id: String
  var title: String
  var iconName: String
  var systemPrompt: String
  var createdAt: Date

  init(
    id: String,
    title: String,
    iconName: String,
    systemPrompt: String,
    createdAt: Date
  ) {
    self.id = id
    self.title = title
    self.iconName = iconName
    self.systemPrompt = systemPrompt
    self.createdAt = createdAt
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case title
    case iconName
    case systemPrompt
    case createdAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    title = try container.decode(String.self, forKey: .title)
    iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? NativeProjectIcon.defaultIcon.systemImage
    systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt) ?? ""
    createdAt = try container.decode(Date.self, forKey: .createdAt)
  }
}

struct NativeProjectIcon: Identifiable, Equatable {
  var id: String { systemImage }
  var systemImage: String
  var title: String

  static let defaultIcon = NativeProjectIcon(systemImage: "folder", title: "폴더")

  static let all: [NativeProjectIcon] = [
    defaultIcon,
    NativeProjectIcon(systemImage: "sparkles", title: "AI"),
    NativeProjectIcon(systemImage: "terminal", title: "코드"),
    NativeProjectIcon(systemImage: "doc.text", title: "문서"),
    NativeProjectIcon(systemImage: "brain.head.profile", title: "메모리"),
    NativeProjectIcon(systemImage: "chart.bar", title: "분석")
  ]
}

enum NativeRenameTarget: Identifiable, Equatable {
  case session(id: String, title: String)
  case project(NativeProject)

  var id: String {
    switch self {
    case .session(let id, _):
      return "session-\(id)"
    case .project(let project):
      return "project-\(project.id)"
    }
  }

  var title: String {
    switch self {
    case .session(_, let title):
      return title
    case .project(let project):
      return project.title
    }
  }

  var navigationTitle: String {
    switch self {
    case .session:
      return "채팅 이름 변경"
    case .project:
      return "프로젝트 설정"
    }
  }

  var fieldTitle: String {
    switch self {
    case .session:
      return "채팅 이름"
    case .project:
      return "프로젝트 이름"
    }
  }

  var placeholder: String {
    switch self {
    case .session:
      return "예: 새 채팅"
    case .project:
      return "예: Atlas"
    }
  }

  var isProject: Bool {
    if case .project = self {
      return true
    }
    return false
  }
}
