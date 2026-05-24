import Foundation
import SwiftUI
import UIKit

enum NativeCitationTagRenderer {
  static func image(number: Int, font: UIFont, accentColor: UIColor) -> UIImage {
    let text = "\(number)"
    let horizontalPadding: CGFloat = 8
    let verticalPadding: CGFloat = 4
    let textSize = (text as NSString).size(withAttributes: [.font: font])
    let size = CGSize(
      width: ceil(textSize.width + horizontalPadding * 2),
      height: ceil(textSize.height + verticalPadding * 2)
    )

    return UIGraphicsImageRenderer(size: size).image { context in
      let rect = CGRect(origin: .zero, size: size)
      let capsule = UIBezierPath(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), cornerRadius: size.height / 2)

      accentColor.withAlphaComponent(0.18).setFill()
      capsule.fill()

      accentColor.withAlphaComponent(0.44).setStroke()
      capsule.lineWidth = 1
      capsule.stroke()

      let dotSize: CGFloat = 3.5
      let dotRect = CGRect(
        x: 5,
        y: (size.height - dotSize) / 2,
        width: dotSize,
        height: dotSize
      )
      context.cgContext.setFillColor(accentColor.withAlphaComponent(0.92).cgColor)
      context.cgContext.fillEllipse(in: dotRect)

      let textRect = CGRect(
        x: horizontalPadding + 2,
        y: (size.height - textSize.height) / 2 - 0.5,
        width: textSize.width,
        height: textSize.height
      )
      (text as NSString).draw(
        in: textRect,
        withAttributes: [
          .font: font,
          .foregroundColor: accentColor
        ]
      )
    }
  }
}
