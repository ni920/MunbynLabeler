import Foundation
import LabelCore

enum SelfTestFailure: Error, CustomStringConvertible {
    case assertion(String)

    var description: String {
        switch self {
        case .assertion(let message): message
        }
    }
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw SelfTestFailure.assertion(message) }
}

do {
    let bitmap = Data([0xAA, 0x55, 0xF0, 0x0F])
    let raster = LabelRaster(width: 16, height: 2, bytesPerRow: 2, bitmap: bitmap)
    let job = TSPLCommandBuilder.bitmapJob(raster: raster, speed: 99, density: 0)
    let bytes = [UInt8](job)

    try require(job.range(of: Data("SIZE 100 mm,150 mm\r\n".utf8)) != nil, "SIZE command missing")
    try require(job.range(of: Data("SPEED 8\r\n".utf8)) != nil, "Speed clamping failed")
    try require(job.range(of: Data("DENSITY 1\r\n".utf8)) != nil, "Density clamping failed")
    try require(job.range(of: Data("BITMAP 0,0,2,2,0,".utf8)) != nil, "BITMAP command missing")
    try require(job.range(of: bitmap) != nil, "Bitmap payload missing")
    try require(Array(bytes.suffix(11)) == [UInt8](Data("PRINT 1,1\r\n".utf8)), "PRINT command missing")

    let testLabel = TSPLCommandBuilder.testLabel(
        title: "A \"Label\"",
        subtitle: "Line 1\nLine 2",
        date: Date(timeIntervalSince1970: 0)
    )
    let text = String(decoding: testLabel, as: UTF8.self)
    try require(text.contains("A \\\"Label\\\""), "Quote escaping failed")
    try require(text.contains("Line 1 Line 2"), "Newline escaping failed")
    try require(text.hasSuffix("PRINT 1,1\r\n"), "Test label is incomplete")

    print("LabelCoreSelfTest: 8 checks passed")
} catch {
    fputs("LabelCoreSelfTest failed: \(error)\n", stderr)
    exit(1)
}
