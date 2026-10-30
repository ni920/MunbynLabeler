import Foundation
import LabelCore

func runCutGuideTests() throws {
    for format in [LabelFormat.continuousLetter100x55, .shipping100x150] {
        // Ink touches every source edge; a cut guide must never overwrite it.
        let stride = (format.widthDots + 7) / 8
        let original = Data((0..<(stride * format.heightDots)).map { UInt8(truncatingIfNeeded: $0 * 37) })
        let source = LabelRaster(width: format.widthDots, height: format.heightDots, bytesPerRow: stride, bitmap: original)
        let result = ContinuousLabelCutGuide.applying(to: source)
        try require(result.width == source.width && result.height == source.height + 16,
                    "Continuous cut strip must add exactly 2 mm without resizing content")
        try require(result.bitmap.prefix(original.count) == original,
                    "Cut guide changed label ink or barcode pixels")
        try require(result.bitmap.count == stride * result.height, "Cut strip produced incomplete raster rows")
        for y in source.height..<result.height {
            for x in 0..<result.width {
                let black = result.bitmap[y * stride + x / 8] & (0x80 >> UInt8(x % 8)) != 0
                let expected = (source.height + 8..<(source.height + 10)).contains(y) &&
                    x >= 16 && x < source.width - 16 && (x - 16) % 24 < 16
                try require(black == expected, "Cut line dash, gap or blank margin is incorrect")
            }
        }
        let printFormat = ContinuousLabelCutGuide.printFormat(for: format)
        try require(printFormat.widthDots == result.width && printFormat.heightDots == result.height,
                    "System print paper size differs from the Bluetooth raster")
    }
    let empty = LabelRaster(width: 0, height: 0, bytesPerRow: 0, bitmap: Data())
    try require(ContinuousLabelCutGuide.applying(to: empty) == empty, "Malformed raster must not be extended")
    print("Cut guide tests passed: 2 mm strip, unchanged content, dash placement and print-size agreement")
}
