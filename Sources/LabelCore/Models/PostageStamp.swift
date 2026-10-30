import CoreGraphics
import Foundation

public struct PostageStamp: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let sourceURL: URL
    public let pageNumber: Int
    public let number: Int
    public let amount: String
    public let sourceRect: CGRect

    public init(id: String, sourceURL: URL, pageNumber: Int, number: Int, amount: String, sourceRect: CGRect) {
        self.id = id
        self.sourceURL = sourceURL
        self.pageNumber = pageNumber
        self.number = number
        self.amount = amount
        self.sourceRect = sourceRect
    }

    /// The complete printed Internetmarke identifier, including leading zeros
    /// and its check digit. Use the PDF's identifier rather than deriving one
    /// from an excerpt of the binary matrix payload.
    public var trackingNumber: String? {
        let value = id.filter { !$0.isWhitespace }.uppercased()
        guard value.count == 20, value.allSatisfy({ "0123456789ABCDEF".contains($0) }) else { return nil }
        return value
    }

    public static func trackingNumbersText(for stamps: [PostageStamp]) -> String {
        stamps.compactMap(\.trackingNumber).joined(separator: "\n")
    }
}

/// Packs complete stamps at their PDF size, in points. No scaling is applied.
public struct PostageSheetLayout: Sendable {
    public struct Placement: Sendable {
        public let stampIndex: Int
        public let rect: CGRect
    }

    public let capacity: Int
    public let columns: Int
    public let sheets: [[Placement]]
    public let cellSize: CGSize
    public let paperSize: CGSize

    public init(stampSizes: [CGSize], format: LabelFormat) {
        let pointsPerMM = 72.0 / 25.4
        let margin = pointsPerMM
        paperSize = CGSize(width: format.widthMM * pointsPerMM, height: format.heightMM * pointsPerMM)
        cellSize = CGSize(width: stampSizes.map(\.width).max() ?? 0, height: stampSizes.map(\.height).max() ?? 0)
        guard cellSize.width.isFinite, cellSize.height.isFinite, cellSize.width > 0, cellSize.height > 0 else {
            columns = 0; capacity = 0; sheets = []; return
        }
        columns = max(0, Int(floor((paperSize.width - 2 * margin) / cellSize.width)))
        let rows = max(0, Int(floor((paperSize.height - 2 * margin) / cellSize.height)))
        capacity = columns * rows
        guard capacity > 0 else { sheets = []; return }
        let originX = (paperSize.width - Double(columns) * cellSize.width) / 2
        var result: [[Placement]] = []
        for start in stride(from: 0, to: stampSizes.count, by: capacity) {
            var sheet: [Placement] = []
            for index in start..<min(start + capacity, stampSizes.count) {
                let slot = index - start
                let size = stampSizes[index]
                let rect = CGRect(
                    x: originX + Double(slot % columns) * cellSize.width + (cellSize.width - size.width) / 2,
                    y: paperSize.height - margin - Double(slot / columns + 1) * cellSize.height + (cellSize.height - size.height) / 2,
                    width: size.width, height: size.height
                )
                sheet.append(Placement(stampIndex: index, rect: rect))
            }
            result.append(sheet)
        }
        sheets = result
    }
}
