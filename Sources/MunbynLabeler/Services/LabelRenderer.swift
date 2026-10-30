import AppKit
import CoreGraphics
import Foundation
import LabelCore

enum LabelRendererError: LocalizedError {
    case unsupportedFile
    case cannotCreateBitmap
    case cannotReadDocument

    var errorDescription: String? {
        switch self {
        case .unsupportedFile: "Dieses Dateiformat wird noch nicht unterstützt."
        case .cannotCreateBitmap: "Die Druckgrafik konnte nicht erzeugt werden."
        case .cannotReadDocument: "Die Datei konnte nicht gelesen werden."
        }
    }
}

enum LabelRenderer {
    static func testPattern(
        format: LabelFormat = .shipping100x150
    ) -> LabelRaster {
        let width = format.widthDots
        let height = format.heightDots
        let bytesPerRow = (width + 7) / 8
        var bitmap = Data(count: bytesPerRow * height)

        func fillRect(x: Int, y: Int, width rectWidth: Int, height rectHeight: Int) {
            let minX = max(0, x)
            let maxX = min(width, x + rectWidth)
            let minY = max(0, y)
            let maxY = min(height, y + rectHeight)
            guard minX < maxX, minY < maxY else { return }
            for row in minY..<maxY {
                for column in minX..<maxX {
                    bitmap[row * bytesPerRow + column / 8] |= 0x80 >> UInt8(column % 8)
                }
            }
        }

        let inset = 28
        let line = 5
        fillRect(x: inset, y: inset, width: width - 2 * inset, height: line)
        fillRect(x: inset, y: height - inset - line, width: width - 2 * inset, height: line)
        fillRect(x: inset, y: inset, width: line, height: height - 2 * inset)
        fillRect(x: width - inset - line, y: inset, width: line, height: height - 2 * inset)

        let glyphs: [[String]] = [
            ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
            ["10001", "10010", "10100", "11000", "10100", "10010", "10001"]
        ]
        let scale = max(5, min(width / 15, height / 12))
        let glyphWidth = 5 * scale
        let gap = scale
        let totalWidth = glyphs.count * glyphWidth + (glyphs.count - 1) * gap
        let originX = (width - totalWidth) / 2
        let originY = (height - 7 * scale) / 2

        for (glyphIndex, rows) in glyphs.enumerated() {
            for (row, values) in rows.enumerated() {
                for (column, value) in values.enumerated() where value == "1" {
                    fillRect(
                        x: originX + glyphIndex * (glyphWidth + gap) + column * scale,
                        y: originY + row * scale,
                        width: scale,
                        height: scale
                    )
                }
            }
        }

        let decorativeWidth = min(width - 2 * inset, scale * 9)
        fillRect(x: width / 2 - decorativeWidth / 2, y: max(inset + line + 10, originY - scale * 2), width: decorativeWidth, height: max(3, scale / 5))
        fillRect(x: width / 2 - decorativeWidth / 3, y: max(inset + line + 18, originY - scale), width: decorativeWidth * 2 / 3, height: max(3, scale / 5))
        fillRect(x: width / 2 - scale, y: min(height - inset - line - 12, originY + 8 * scale), width: 2 * scale, height: max(4, scale / 4))

        return LabelRaster(width: width, height: height, bytesPerRow: bytesPerRow, bitmap: bitmap)
    }

    static func render(
        url: URL,
        format: LabelFormat = .shipping100x150,
        threshold: UInt8 = 170
    ) throws -> LabelRaster {
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = CGPDFDocument(url as CFURL), let page = document.page(at: 1) else {
                throw LabelRendererError.cannotReadDocument
            }
            return try render(page: page, format: format, threshold: threshold)
        }
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw LabelRendererError.unsupportedFile
        }
        return try render(format: format, threshold: threshold) { context, canvas in
            context.draw(cgImage, in: aspectFit(CGSize(width: cgImage.width, height: cgImage.height), in: canvas))
        }
    }

    static func render(pdfData: Data, format: LabelFormat) throws -> LabelRaster {
        guard let provider = CGDataProvider(data: pdfData as CFData),
              let document = CGPDFDocument(provider), let page = document.page(at: 1) else {
            throw LabelRendererError.cannotReadDocument
        }
        return try render(page: page, format: format, threshold: 170)
    }

    private static func render(page: CGPDFPage, format: LabelFormat, threshold: UInt8) throws -> LabelRaster {
        try render(format: format, threshold: threshold) { context, canvas in
            let placement = PDFLabelPlacement.resolve(pageBounds: page.getBoxRect(.mediaBox), labelFormat: format)
            context.saveGState()
            context.concatenate(placement.drawingTransform(in: canvas))
            context.clip(to: placement.sourceRect)
            context.drawPDFPage(page)
            context.restoreGState()
        }
    }

    private static func render(
        format: LabelFormat, threshold: UInt8, draw: (CGContext, CGRect) -> Void
    ) throws -> LabelRaster {
        let width = format.widthDots
        let height = format.heightDots
        var grayscale = [UInt8](repeating: 255, count: width * height)
        guard let context = CGContext(
            data: &grayscale, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { throw LabelRendererError.cannotCreateBitmap }
        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(canvas)
        context.interpolationQuality = .high
        draw(context, canvas)

        let bytesPerRow = (width + 7) / 8
        var packed = Data(count: bytesPerRow * height)
        packed.withUnsafeMutableBytes { destination in
            guard let output = destination.bindMemory(to: UInt8.self).baseAddress else { return }
            for y in 0..<height {
                for x in 0..<width where grayscale[y * width + x] < threshold {
                    let byteIndex = y * bytesPerRow + x / 8
                    output[byteIndex] |= 0x80 >> UInt8(x % 8)
                }
            }
        }

        return LabelRaster(width: width, height: height, bytesPerRow: bytesPerRow, bitmap: packed)
    }

    private static func aspectFit(_ source: CGSize, in destination: CGRect) -> CGRect {
        guard source.width > 0, source.height > 0 else { return destination }
        let scale = min(destination.width / source.width, destination.height / source.height)
        let size = CGSize(width: source.width * scale, height: source.height * scale)
        return CGRect(
            x: destination.midX - size.width / 2,
            y: destination.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
