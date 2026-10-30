import CoreGraphics
import Foundation
import PDFKit

public enum PostagePDFError: LocalizedError {
    case unreadable, unsupportedLayout, formatTooSmall, cannotWrite

    public var errorDescription: String? {
        switch self {
        case .unreadable: "Das Briefmarken-PDF konnte nicht gelesen werden."
        case .unsupportedLayout: "Keine vollständigen Internetmarken erkannt. Unterstützt werden PDF-Bündel mit dem kompakten Internetmarken-Layout ohne Motiv oder Anschrift."
        case .formatTooSmall: "Die Marken passen in Originalgröße nicht auf dieses Etikett. Bitte ein größeres Format wählen."
        case .cannotWrite: "Der Briefmarkenbogen konnte nicht erstellt werden."
        }
    }
}

public enum PostagePDFService {
    public static func readStamps(from url: URL) throws -> [PostageStamp] {
        guard let document = PDFDocument(url: url), !document.isLocked else { throw PostagePDFError.unreadable }
        let pattern = #"IM[ \t]+\d{2}\.\d{2}\.\d{2}[ \t]+(\d+[,\.]\d{2})\s+([A-Fa-f0-9]{2}[ \t]+[A-Fa-f0-9]{4}[ \t]+[A-Fa-f0-9]{4})\s+([A-Fa-f0-9]{2}[ \t]+[A-Fa-f0-9]{4}[ \t]+[A-Fa-f0-9]{4})"#
        let regex = try NSRegularExpression(pattern: pattern)
        var found: [(String, Int, String, CGRect)] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index), let text = page.string else { continue }
            let ns = text as NSString
            for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let headerRange = NSRange(location: match.range.location, length: match.range(at: 1).upperBound - match.range.location)
                guard let header = page.selection(for: headerRange) else { continue }
                let anchor = header.bounds(for: page)
                // Compact Deutsche Post layout: matrix to the left, logo above,
                // two identifier lines below. Keep whitespace around all ink.
                let crop = CGRect(x: anchor.minX - 42, y: anchor.minY - 41,
                                  width: anchor.width + 47, height: anchor.height + 59)
                guard page.rotation == 0, page.bounds(for: .mediaBox).contains(crop) else {
                    throw PostagePDFError.unsupportedLayout
                }
                let identifier = (ns.substring(with: match.range(at: 2)) + ns.substring(with: match.range(at: 3)))
                    .filter { !$0.isWhitespace }.uppercased()
                found.append((identifier, index + 1, ns.substring(with: match.range(at: 1)), crop))
            }
        }
        guard !found.isEmpty else { throw PostagePDFError.unsupportedLayout }
        // Page reading order may be column-first. Display and pack row-first.
        found.sort { a, b in
            if a.1 != b.1 { return a.1 < b.1 }
            if abs(a.3.midY - b.3.midY) > 4 { return a.3.midY > b.3.midY }
            return a.3.minX < b.3.minX
        }
        var seen = Set<String>()
        return found.enumerated().compactMap { number, item in
            guard seen.insert(item.0).inserted else { return nil }
            return PostageStamp(id: item.0, sourceURL: url, pageNumber: item.1,
                                number: number + 1, amount: item.2, sourceRect: item.3)
        }
    }

    public static func writeSheets(stamps: [PostageStamp], format: LabelFormat, cutGuides: Bool, directory: URL) throws -> [(URL, [String])] {
        let layout = PostageSheetLayout(stampSizes: stamps.map { $0.sourceRect.size }, format: format)
        guard layout.capacity > 0, !layout.sheets.isEmpty else { throw PostagePDFError.formatTooSmall }
        var documents: [URL: CGPDFDocument] = [:]
        var output: [(URL, [String])] = []
        for placements in layout.sheets {
            let target = directory.appendingPathComponent("briefmarken-\(UUID().uuidString).pdf")
            var mediaBox = CGRect(origin: .zero, size: layout.paperSize)
            guard let context = CGContext(target as CFURL, mediaBox: &mediaBox, nil) else { throw PostagePDFError.cannotWrite }
            context.beginPDFPage(nil)
            for placement in placements {
                let stamp = stamps[placement.stampIndex]
                if documents[stamp.sourceURL] == nil { documents[stamp.sourceURL] = CGPDFDocument(stamp.sourceURL as CFURL) }
                guard let page = documents[stamp.sourceURL]?.page(at: stamp.pageNumber) else {
                    context.endPDFPage(); context.closePDF(); throw PostagePDFError.unreadable
                }
                context.saveGState()
                context.clip(to: placement.rect)
                context.translateBy(x: placement.rect.minX - stamp.sourceRect.minX, y: placement.rect.minY - stamp.sourceRect.minY)
                context.drawPDFPage(page)
                context.restoreGState()
            }
            if cutGuides {
                // Fine black dashes survive the printer's 1-bit threshold.
                context.setStrokeColor(gray: 0, alpha: 1)
                context.setLineWidth(0.35)
                context.setLineDash(phase: 0, lengths: [2, 3])
                let left = (layout.paperSize.width - Double(layout.columns) * layout.cellSize.width) / 2
                let top = layout.paperSize.height - 72.0 / 25.4
                let rows = Int(ceil(Double(placements.count) / Double(layout.columns)))
                if layout.columns > 1 {
                    for column in 1..<layout.columns {
                        let x = left + Double(column) * layout.cellSize.width
                        context.move(to: CGPoint(x: x, y: top)); context.addLine(to: CGPoint(x: x, y: top - Double(rows) * layout.cellSize.height))
                    }
                }
                if rows > 1 {
                    for row in 1..<rows {
                        let y = top - Double(row) * layout.cellSize.height
                        context.move(to: CGPoint(x: left, y: y)); context.addLine(to: CGPoint(x: left + Double(layout.columns) * layout.cellSize.width, y: y))
                    }
                }
                context.strokePath()
            }
            context.endPDFPage(); context.closePDF()
            output.append((target, placements.map { stamps[$0.stampIndex].id }))
        }
        return output
    }
}
