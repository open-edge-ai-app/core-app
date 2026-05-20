import Foundation
import SwiftUI
import UIKit

extension Color {
  static var oeBackground: Color { Color(uiColor: .systemBackground) }
  static var oeGroupedBackground: Color { Color(uiColor: .systemGroupedBackground) }
  static var oeSurface: Color { Color(uiColor: .secondarySystemGroupedBackground) }
  static var oeElevatedSurface: Color { Color(uiColor: .tertiarySystemGroupedBackground) }
  static var oeText: Color { Color(uiColor: .label) }
  static var oeSecondaryText: Color { Color(uiColor: .secondaryLabel) }
  static var oeMutedText: Color { Color(uiColor: .tertiaryLabel) }
  static var oeSubtleFill: Color { Color(uiColor: .secondarySystemFill) }
  static var oeSoftFill: Color { Color(uiColor: .tertiarySystemFill) }
  static var oeBorder: Color { Color(uiColor: .separator) }
  static var oeSeparator: Color { Color(uiColor: .separator) }
  static var oeControlFill: Color { Color(uiColor: .label) }
  static var oeControlText: Color { Color(uiColor: .systemBackground) }
  static var oeDestructive: Color { Color(uiColor: .systemRed) }
  static var oeNowIndicator: Color { Color(uiColor: .systemRed) }
}
