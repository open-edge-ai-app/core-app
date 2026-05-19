import Foundation
import SwiftUI

import Foundation
import SwiftUI

extension Color {
  static var oeBackground: Color { Color(.systemBackground) }
  static var oeGroupedBackground: Color { Color(.systemGroupedBackground) }
  static var oeSurface: Color { Color(.secondarySystemBackground) }
  static var oeElevatedSurface: Color { Color(.tertiarySystemBackground) }
  static var oeText: Color { .primary }
  static var oeSecondaryText: Color { .primary.opacity(0.62) }
  static var oeMutedText: Color { .primary.opacity(0.45) }
  static var oeSubtleFill: Color { .primary.opacity(0.055) }
  static var oeBorder: Color { .primary.opacity(0.10) }
  static var oeControlFill: Color { .primary }
  static var oeControlText: Color { Color(.systemBackground) }
}
