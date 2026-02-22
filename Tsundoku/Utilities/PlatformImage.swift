#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage

extension NSImage {
    var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    var scale: CGFloat { 1.0 }
}

extension CIImage {
    convenience init?(image: NSImage) {
        guard let cgImage = image.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
}
#endif
