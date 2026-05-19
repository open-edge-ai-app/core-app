import Foundation

struct NativeTodoToolCall {
  var name: String
  var arguments: [String: Any]
}

enum NativeTodoToolParser {
  static func extractCalls(from text: String) -> (cleanedText: String, calls: [NativeTodoToolCall]) {
    var cleanedText = text
    var calls: [NativeTodoToolCall] = []
    let nsText = text as NSString
    let pattern = #"(?s)```(?:openedge_tool|openedge-tool|openedge_tool_call|todo_tool)\s*(.*?)\s*```"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return (text, [])
    }

    let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
    for match in matches.reversed() {
      guard match.numberOfRanges > 1 else {
        continue
      }
      let payloadRange = match.range(at: 1)
      guard payloadRange.location != NSNotFound else {
        continue
      }
      let payload = nsText.substring(with: payloadRange)
      calls.append(contentsOf: parsePayload(payload))
      if let range = Range(match.range, in: cleanedText) {
        cleanedText.removeSubrange(range)
      }
    }

    return (cleanedText.trimmingCharacters(in: .whitespacesAndNewlines), calls.reversed())
  }

  private static func parsePayload(_ payload: String) -> [NativeTodoToolCall] {
    let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let data = trimmed.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data)
    else {
      return []
    }

    if let array = json as? [[String: Any]] {
      return array.compactMap(makeCall)
    }

    if let dictionary = json as? [String: Any] {
      if let calls = dictionary["calls"] as? [[String: Any]] {
        return calls.compactMap(makeCall)
      }
      if let calls = dictionary["tool_calls"] as? [[String: Any]] {
        return calls.compactMap(makeCall)
      }
      if let call = makeCall(from: dictionary) {
        return [call]
      }
    }

    return []
  }

  private static func makeCall(from dictionary: [String: Any]) -> NativeTodoToolCall? {
    let rawName = dictionary["tool"] as? String
      ?? dictionary["name"] as? String
      ?? dictionary["tool_name"] as? String
    guard let name = rawName?.trimmingCharacters(in: .whitespacesAndNewlines),
          name.hasPrefix("todo_")
    else {
      return nil
    }

    let arguments = dictionary["arguments"] as? [String: Any]
      ?? dictionary["args"] as? [String: Any]
      ?? dictionary.filter { key, _ in
        key != "tool" && key != "name" && key != "tool_name"
      }
    return NativeTodoToolCall(name: name, arguments: arguments)
  }
}

extension Dictionary where Key == String, Value == Any {
  func todoString(_ keys: String...) -> String? {
    for key in keys {
      if let value = self[key] as? String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
          return trimmed
        }
      }
      if let value = self[key] as? NSNumber {
        return value.stringValue
      }
    }
    return nil
  }

  func todoBool(_ keys: String...) -> Bool? {
    for key in keys {
      if let value = self[key] as? Bool {
        return value
      }
      if let value = self[key] as? NSNumber {
        return value.boolValue
      }
      if let value = self[key] as? String {
        switch value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "true", "yes", "on", "1", "완료", "켜기", "활성":
          return true
        case "false", "no", "off", "0", "미완료", "끄기", "비활성":
          return false
        default:
          break
        }
      }
    }
    return nil
  }

  func todoStringArray(_ keys: String...) -> [String]? {
    for key in keys {
      if let values = self[key] as? [String] {
        return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
      }
      if let values = self[key] as? [Any] {
        let strings = values.compactMap { value -> String? in
          if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
          }
          if let number = value as? NSNumber {
            return number.stringValue
          }
          return nil
        }
        return strings.filter { !$0.isEmpty }
      }
      if let value = self[key] as? String {
        return value
          .split { $0 == "," || $0 == "\n" }
          .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
          .filter { !$0.isEmpty }
      }
    }
    return nil
  }
}
