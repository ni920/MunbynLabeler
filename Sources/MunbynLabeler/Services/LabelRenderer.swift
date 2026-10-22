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
    static func render(
        url: URL,
        width: Int = TSPLCommandBuilder.defaultWidthDots,
        height: Int = TSPLCommandBuilder.defaultHeightDots,
        threshold: UInt8 = 170
    ) throws -> LabelRaster {
        var grayscale = [UInt8](repeating: 255, count: width * height)
        guard let context = CGContext(
            data: &grayscale,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw LabelRendererError.cannotCreateBitmap
        }

        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high

        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = CGPDFDocument(url as CFURL),
                  let page = document.page(at: 1) else {
                throw LabelRendererError.cannotReadDocument
            }
            let source = page.getBoxRect(.mediaBox)
            let target = aspectFit(source.size, in: canvas)
            context.saveGState()
            context.translateBy(x: target.minX, y: target.minY)
            context.scaleBy(x: target.width / source.width, y: target.height / source.height)
            context.translateBy(x: -source.minX, y: -source.minY)
            context.drawPDFPage(page)
            context.restoreGState()
        } else {
            guard let image = NSImage(contentsOf: url),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw LabelRendererError.unsupportedFile
            }
            let target = aspectFit(CGSize(width: cgImage.width, height: cgImage.height), in: canvas)
            context.draw(cgImage, in: target)
        }

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
