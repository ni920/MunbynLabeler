import Foundation

public struct LabelRaster: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let bytesPerRow: Int
    public let bitmap: Data

    public init(width: Int, height: Int, bytesPerRow: Int, bitmap: Data) {
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.bitmap = bitmap
    }
}
