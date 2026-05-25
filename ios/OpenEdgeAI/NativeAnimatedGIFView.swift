import ImageIO
import SwiftUI
import UIKit

struct NativeAnimatedGIFView: UIViewRepresentable {
  var name: String

  func makeUIView(context: Context) -> UIImageView {
    let imageView = UIImageView()
    imageView.backgroundColor = .clear
    imageView.clipsToBounds = true
    imageView.contentMode = .scaleAspectFit
    imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    configure(imageView)
    return imageView
  }

  func updateUIView(_ imageView: UIImageView, context: Context) {
    configure(imageView)
  }

  private func configure(_ imageView: UIImageView) {
    imageView.image = NativeAnimatedGIFCache.image(named: name)
    imageView.startAnimating()
  }
}

enum NativeAnimatedGIFCache {
  private static let cache = NSCache<NSString, UIImage>()

  static func image(named name: String) -> UIImage? {
    let key = name as NSString
    if let cached = cache.object(forKey: key) {
      return cached
    }

    guard
      let url = Bundle.main.url(forResource: name, withExtension: "gif"),
      let data = try? Data(contentsOf: url),
      let source = CGImageSourceCreateWithData(data as CFData, nil)
    else {
      return nil
    }

    let frameCount = CGImageSourceGetCount(source)
    var images: [UIImage] = []
    var duration: TimeInterval = 0

    for index in 0..<frameCount {
      guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else {
        continue
      }

      let frameDuration = gifFrameDuration(at: index, source: source)
      duration += frameDuration
      images.append(UIImage(cgImage: cgImage))
    }

    guard let animatedImage = UIImage.animatedImage(with: images, duration: max(duration, 0.12)) else {
      return nil
    }

    cache.setObject(animatedImage, forKey: key)
    return animatedImage
  }

  private static func gifFrameDuration(at index: Int, source: CGImageSource) -> TimeInterval {
    guard
      let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
      let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
    else {
      return 0.12
    }

    let unclampedDelay = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval
    let delay = gifProperties[kCGImagePropertyGIFDelayTime] as? TimeInterval
    return max(unclampedDelay ?? delay ?? 0.12, 0.04)
  }
}
