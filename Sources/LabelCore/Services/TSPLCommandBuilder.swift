import Foundation

public enum TSPLCommandBuilder {
    public static let defaultWidthDots = 800
    public static let defaultHeightDots = 1_200

    public static func bitmapJob(
        raster: LabelRaster,
        widthMillimeters: Int = 100,
        heightMillimeters: Int = 150,
        gapMillimeters: Int = 3,
        speed: Int = 4,
        density: Int = 8,
        copies: Int = 1
    ) -> Data {
        var data = Data()
        data.appendASCII("SIZE \(widthMillimeters) mm,\(heightMillimeters) mm\r\n")
        data.appendASCII("GAP \(gapMillimeters) mm,0 mm\r\n")
        data.appendASCII("SPEED \(clamp(speed, to: 1...8))\r\n")
        data.appendASCII("DENSITY \(clamp(density, to: 1...15))\r\n")
        data.appendASCII("DIRECTION 1\r\n")
        data.appendASCII("REFERENCE 0,0\r\n")
        data.appendASCII("CLS\r\n")
        data.appendASCII("BITMAP 0,0,\(raster.bytesPerRow),\(raster.height),0,")
        data.append(raster.bitmap)
        data.appendASCII("\r\nPRINT \(max(1, copies)),1\r\n")
        return data
    }

    public static func testLabel(
        title: String = "RW403B VERBUNDEN",
        subtitle: String = "Label Helper Bluetooth-Test",
        date: Date = Date()
    ) -> Data {
        let timestamp = ISO8601DateFormatter().string(from: date)
        var data = Data()
        data.appendASCII("SIZE 100 mm,150 mm\r\n")
        data.appendASCII("GAP 3 mm,0 mm\r\n")
        data.appendASCII("SPEED 4\r\n")
        data.appendASCII("DENSITY 8\r\n")
        data.appendASCII("DIRECTION 1\r\n")
        data.appendASCII("CLS\r\n")
        data.appendASCII("BOX 24,24,776,1176,4\r\n")
        data.appendASCII("TEXT 56,90,\"3\",0,2,2,\"\(escape(title))\"\r\n")
        data.appendASCII("TEXT 56,180,\"3\",0,1,1,\"\(escape(subtitle))\"\r\n")
        data.appendASCII("BARCODE 56,280,\"128\",120,1,0,2,3,\"MUNBYN-RW403B\"\r\n")
        data.appendASCII("QRCODE 56,500,L,8,A,0,\"MUNBYN-RW403B\"\r\n")
        data.appendASCII("TEXT 56,1040,\"2\",0,1,1,\"\(escape(timestamp))\"\r\n")
        data.appendASCII("PRINT 1,1\r\n")
        return data
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(string.data(using: .ascii, allowLossyConversion: true) ?? Data())
    }
}
