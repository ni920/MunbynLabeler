import Foundation

/// A separate cut strip keeps address text and paid barcodes untouched.
public enum ContinuousLabelCutGuide {
    public static let extraLengthMM = 2.0

    public static func printFormat(for contentFormat: LabelFormat) -> LabelFormat {
        LabelFormat(id: contentFormat.id + "-cut-guide", name: contentFormat.name,
                    widthMM: contentFormat.widthMM, heightMM: contentFormat.heightMM + extraLengthMM)
    }

    public static func applying(to raster: LabelRaster) -> LabelRaster {
        guard raster.width > 0, raster.height > 0,
              raster.bytesPerRow == (raster.width + 7) / 8,
              raster.bitmap.count == raster.bytesPerRow * raster.height else { return raster }
        let dotsPerMM = Int(LabelFormat.dotsPerMillimeter)
        let extraRows = Int(extraLengthMM * LabelFormat.dotsPerMillimeter)
        let margin = 2 * dotsPerMM
        let dash = 2 * dotsPerMM
        let gap = dotsPerMM
        let lineY = raster.height + dotsPerMM
        var bitmap = raster.bitmap
        bitmap.append(Data(count: raster.bytesPerRow * extraRows))
        for y in lineY..<(lineY + 2) {
            for x in margin..<max(margin, raster.width - margin) where (x - margin) % (dash + gap) < dash {
                bitmap[y * raster.bytesPerRow + x / 8] |= 0x80 >> UInt8(x % 8)
            }
        }
        return LabelRaster(width: raster.width, height: raster.height + extraRows,
                           bytesPerRow: raster.bytesPerRow, bitmap: bitmap)
    }
}
