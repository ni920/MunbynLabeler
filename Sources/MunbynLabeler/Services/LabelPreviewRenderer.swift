import AppKit
import CoreGraphics
import Foundation
import LabelCore

enum LabelPreviewRenderer {
    static func image(from raster: LabelRaster) -> NSImage? {
        guard raster.width > 0,
              raster.height > 0,
              raster.bytesPerRow > 0,
              raster.bitmap.count >= raster.bytesPerRow * raster.height else {
            return nil
        }

        var grayscale = Data(repeating: 255, count: raster.width * raster.height)
        grayscale.withUnsafeMutableBytes { destination in
            guard let pixels = destination.bindMemory(to: UInt8.self).baseAddress else { return }
            raster.bitmap.withUnsafeBytes { source in
                guard let packed = source.bindMemory(to: UInt8.self).baseAddress else { return }
                for y in 0..<raster.height {
                    for x in 0..<raster.width {
                        let byte = packed[y * raster.bytesPerRow + x / 8]
                        if byte & (0x80 >> UInt8(x % 8)) != 0 {
                            pixels[y * raster.width + x] = 0
                        }
                    }
                }
            }
        }

        guard let provider = CGDataProvider(data: grayscale as CFData),
              let image = CGImage(
                  width: raster.width,
                  height: raster.height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 8,
                  bytesPerRow: raster.width,
                  space: CGColorSpaceCreateDeviceGray(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              ) else {
            return nil
        }

        return NSImage(cgImage: image, size: NSSize(width: raster.width, height: raster.height))
    }
}
