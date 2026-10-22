import Foundation

public enum MunbynRW403BProtocol {
    public static let serviceUUID = "ABF0"
    public static let notifyCharacteristicUUID = "ABF3"
    public static let dataCharacteristicUUID = "ABF4"
    public static let controlCharacteristicUUID = "ABF1"

    public enum Event: Int, Sendable {
        case deviceInfo = 1
        case selfTest = 2
        case devicePrint = 4
        case cancelPrinting = 5
        case deviceReport = 6
        case printingSpeed = 8
        case printConcentration = 9
        case printEnd = 10
    }

    public static func selfTestFrame() -> Data {
        frame(sendMessage(event: .selfTest))
    }

    public static func deviceInfoFrame() -> Data {
        frame(sendMessage(event: .deviceInfo))
    }

    public static func printEndFrame() -> Data {
        frame(sendMessage(event: .printEnd))
    }

    public static func printSections(
        raster: LabelRaster,
        maximumImageChunkLength: Int = 400
    ) -> [MunbynPrintSection] {
        guard !raster.bitmap.isEmpty else { return [] }

        let wholeCompressedLength = HeatshrinkCodec.compress(raster.bitmap).count
        let baseSectionLength = wholeCompressedLength > 30_720 ? 4_608 : 8_192
        let alignment = max(1, raster.bytesPerRow)
        let sectionLength = max(alignment, baseSectionLength - baseSectionLength % alignment)
        let sourceSections = raster.bitmap.chunked(maximumLength: sectionLength)
        let totalSections = sourceSections.count
        let imageChunkLength = max(20, min(400, maximumImageChunkLength))

        return sourceSections.enumerated().map { sectionOffset, source in
            let compressed = HeatshrinkCodec.compress(source)
            let imageChunks = compressed.chunked(maximumLength: imageChunkLength)
            let frames = imageChunks.enumerated().map { packetOffset, imageData in
                let printMessage = makePrintMessage(
                    page: 1,
                    imageData: imageData,
                    dataLength: raster.bitmap.count,
                    totalPackages: imageChunks.count,
                    packageIndex: packetOffset + 1,
                    width: packetOffset == 0 ? raster.width : 0,
                    totalSections: totalSections,
                    compression: 1,
                    sectionLength: compressed.count,
                    sectionIndex: sectionOffset + 1
                )
                return frame(sendMessage(event: .devicePrint, payload: printMessage))
            }
            return MunbynPrintSection(
                index: sectionOffset + 1,
                uncompressedLength: source.count,
                compressedLength: compressed.count,
                frames: frames
            )
        }
    }

    public static func parseResponse(_ payload: Data) -> MunbynPrinterResponse? {
        var reader = ProtobufReader(data: payload)
        var event = 0
        var statusCode = 0
        var responseData = Data()
        var errorData = Data()

        while let field = reader.nextField() {
            switch (field.number, field.wireType) {
            case (1, 0): event = Int(reader.readVarint() ?? 0)
            case (2, 0): statusCode = Int(reader.readVarint() ?? 0)
            case (3, 2): responseData = reader.readLengthDelimited() ?? Data()
            case (4, 2): errorData = reader.readLengthDelimited() ?? Data()
            default: reader.skip(wireType: field.wireType)
            }
        }

        if event == Event.deviceReport.rawValue {
            let code = parseCodeMessage(responseData)
            if code.code == 11, code.info == "2" {
                return .sectionAccepted
            }
            if code.code == 10 {
                return .printStatus(code.info)
            }
            return .report(code: code.code, info: code.info)
        }

        if event == Event.deviceInfo.rawValue, !responseData.isEmpty {
            let info = parseDeviceInfo(responseData)
            return .deviceInfo(
                printStatus: info.printStatus,
                paperStatus: info.paperStatus,
                firmware: info.firmware
            )
        }

        if statusCode != 0, statusCode != 200 {
            let code = parseCodeMessage(errorData.isEmpty ? responseData : errorData)
            let detail = code.info.isEmpty ? "Status \(statusCode)" : code.info
            return .error(detail)
        }

        return .acknowledgement(event: event, status: statusCode)
    }

    private static func parseCodeMessage(_ data: Data) -> (code: Int, info: String) {
        var reader = ProtobufReader(data: data)
        var code = 0
        var info = ""
        while let field = reader.nextField() {
            switch (field.number, field.wireType) {
            case (1, 0): code = Int(reader.readVarint() ?? 0)
            case (2, 2):
                if let bytes = reader.readLengthDelimited() {
                    info = String(data: bytes, encoding: .utf8) ?? ""
                }
            default: reader.skip(wireType: field.wireType)
            }
        }
        return (code, info)
    }

    private static func parseDeviceInfo(_ data: Data) -> (printStatus: Int, paperStatus: Int, firmware: String) {
        var reader = ProtobufReader(data: data)
        var printStatus = 0
        var paperStatus = 0
        var firmware = ""
        while let field = reader.nextField() {
            switch (field.number, field.wireType) {
            case (3, 2):
                if let bytes = reader.readLengthDelimited() {
                    firmware = String(data: bytes, encoding: .utf8) ?? ""
                }
            case (4, 0): paperStatus = Int(reader.readVarint() ?? 0)
            case (9, 2):
                if let bytes = reader.readLengthDelimited(),
                   let value = String(data: bytes, encoding: .utf8) {
                    printStatus = Int(value) ?? 0
                }
            default: reader.skip(wireType: field.wireType)
            }
        }
        return (printStatus, paperStatus, firmware)
    }

    private static func sendMessage(event: Event, payload: Data = Data()) -> Data {
        var writer = ProtobufWriter()
        writer.writeVarintField(1, UInt64(event.rawValue))
        if !payload.isEmpty {
            writer.writeBytesField(5, payload)
        }
        return writer.data
    }

    private static func makePrintMessage(
        page: Int,
        imageData: Data,
        dataLength: Int,
        totalPackages: Int,
        packageIndex: Int,
        width: Int,
        totalSections: Int,
        compression: Int,
        sectionLength: Int,
        sectionIndex: Int
    ) -> Data {
        var writer = ProtobufWriter()
        writer.writeVarintField(1, UInt64(page))
        writer.writeBytesField(2, imageData)
        writer.writeSignedVarintField(3, dataLength)
        writer.writeVarintField(4, UInt64(totalPackages))
        writer.writeVarintField(5, UInt64(packageIndex))
        if width > 0 { writer.writeVarintField(6, UInt64(width)) }
        writer.writeVarintField(7, UInt64(totalSections))
        writer.writeVarintField(8, UInt64(compression))
        writer.writeSignedVarintField(10, sectionLength)
        writer.writeVarintField(12, UInt64(sectionIndex))
        return writer.data
    }

    private static func frame(_ payload: Data) -> Data {
        precondition(payload.count <= 0x3FFF, "RW403B frame payload is too large")
        var framed = Data(count: payload.count + 4)
        framed[0] = 0x55
        framed[1] = UInt8(payload.count & 0xFF)
        framed[2] = UInt8((payload.count >> 8) & 0xFF)

        var checksum = framed[0] ^ framed[1] ^ framed[2]
        framed[2] |= (checksum & 0x0C) << 4
        framed[3] = (checksum >> 4) & 0x03
        for byte in payload { checksum ^= byte }
        framed[3] |= checksum & 0xFC
        framed.replaceSubrange(4..., with: payload)
        return framed
    }
}

public struct MunbynPrintSection: Sendable {
    public let index: Int
    public let uncompressedLength: Int
    public let compressedLength: Int
    public let frames: [Data]

    public init(index: Int, uncompressedLength: Int, compressedLength: Int, frames: [Data]) {
        self.index = index
        self.uncompressedLength = uncompressedLength
        self.compressedLength = compressedLength
        self.frames = frames
    }
}

public enum MunbynPrinterResponse: Equatable, Sendable {
    case deviceInfo(printStatus: Int, paperStatus: Int, firmware: String)
    case sectionAccepted
    case printStatus(String)
    case report(code: Int, info: String)
    case acknowledgement(event: Int, status: Int)
    case error(String)

    public var diagnosticDescription: String {
        switch self {
        case .deviceInfo(let printStatus, let paperStatus, let firmware):
            "Geräteinfo: Druckstatus \(printStatus), Papierstatus \(paperStatus), Firmware \(firmware.isEmpty ? "unbekannt" : firmware)"
        case .sectionAccepted: "Datenabschnitt bestätigt"
        case .printStatus(let status): "Druckstatus: \(status)"
        case .report(let code, let info): "Druckermeldung \(code): \(info)"
        case .acknowledgement(let event, let status): "Antwort Ereignis \(event), Status \(status)"
        case .error(let detail): "Druckerfehler: \(detail)"
        }
    }
}

public struct MunbynFrameDecoder: Sendable {
    private var state = 0
    private var frameLength = 0
    private var checksum: UInt8 = 0
    private var checkByte: UInt8 = 0
    private var payload = Data()

    public init() {}

    public mutating func append(_ data: Data) -> [Data] {
        var frames: [Data] = []
        for byte in data {
            switch state {
            case 0:
                if byte == 0x55 {
                    state = 1
                    checksum = 0x55
                    frameLength = 0
                    payload.removeAll(keepingCapacity: true)
                }
            case 1:
                frameLength = Int(byte)
                checksum ^= byte
                state = 2
            case 2:
                frameLength |= Int(byte) << 8
                checksum ^= byte & 0x3F
                guard frameLength & 0x3FFF <= 1_156 else {
                    reset()
                    continue
                }
                state = 3
            case 3:
                checkByte = byte
                let headerCheck = ((byte & 0x03) << 4) | UInt8((frameLength >> 12) & 0x0F)
                guard headerCheck == checksum & 0x3C else {
                    reset()
                    continue
                }
                frameLength &= 0x3FFF
                if frameLength == 0 {
                    reset()
                } else {
                    state = 4
                }
            default:
                payload.append(byte)
                checksum ^= byte
                if payload.count == frameLength {
                    if checksum & 0xFC == checkByte & 0xFC {
                        frames.append(payload)
                    }
                    reset()
                }
            }
        }
        return frames
    }

    private mutating func reset() {
        state = 0
        frameLength = 0
        checksum = 0
        checkByte = 0
        payload.removeAll(keepingCapacity: true)
    }
}

public enum HeatshrinkCodec {
    // The RW403B editor ships heatshrink with window=11 and lookahead=4.
    private static let windowBits = 11
    private static let lookaheadBits = 4
    private static let windowSize = 1 << windowBits
    private static let maximumMatchLength = 1 << lookaheadBits

    public static func compress(_ data: Data) -> Data {
        let bytes = [UInt8](data)
        var writer = BitWriter()
        var index = 0

        while index < bytes.count {
            let searchStart = max(0, index - windowSize)
            let maximumLength = min(maximumMatchLength, bytes.count - index)
            var bestDistance = 0
            var bestLength = 0

            if maximumLength >= 2, index > 0 {
                var candidate = index - 1
                while candidate >= searchStart {
                    if bytes[candidate] == bytes[index] {
                        var length = 1
                        while length < maximumLength,
                              bytes[candidate + length] == bytes[index + length] {
                            length += 1
                        }
                        if length > bestLength {
                            bestLength = length
                            bestDistance = index - candidate
                            if length == maximumLength { break }
                        }
                    }
                    if candidate == searchStart { break }
                    candidate -= 1
                }
            }

            if bestLength >= 3 {
                writer.append(value: 0, bitCount: 1)
                writer.append(value: bestDistance - 1, bitCount: windowBits)
                writer.append(value: bestLength - 1, bitCount: lookaheadBits)
                index += bestLength
            } else {
                writer.append(value: 1, bitCount: 1)
                writer.append(value: Int(bytes[index]), bitCount: 8)
                index += 1
            }
        }

        return writer.finish()
    }

    public static func decompress(_ data: Data) -> Data? {
        var reader = BitReader(data: data)
        var output = Data()

        while let tag = reader.read(bitCount: 1) {
            if tag == 1 {
                guard let literal = reader.read(bitCount: 8) else { break }
                output.append(UInt8(literal))
            } else {
                guard let encodedDistance = reader.read(bitCount: windowBits),
                      let encodedLength = reader.read(bitCount: lookaheadBits) else { break }
                let distance = encodedDistance + 1
                let length = encodedLength + 1
                guard distance <= output.count else { return nil }
                for _ in 0..<length {
                    output.append(output[output.count - distance])
                }
            }
        }
        return output
    }
}

private struct ProtobufWriter {
    var data = Data()

    mutating func writeVarintField(_ field: Int, _ value: UInt64) {
        writeVarint(UInt64(field << 3))
        writeVarint(value)
    }

    mutating func writeSignedVarintField(_ field: Int, _ value: Int) {
        let signed = Int64(value)
        let zigzag = UInt64(bitPattern: (signed << 1) ^ (signed >> 63))
        writeVarintField(field, zigzag)
    }

    mutating func writeBytesField(_ field: Int, _ value: Data) {
        writeVarint(UInt64((field << 3) | 2))
        writeVarint(UInt64(value.count))
        data.append(value)
    }

    private mutating func writeVarint(_ value: UInt64) {
        var remaining = value
        repeat {
            var byte = UInt8(remaining & 0x7F)
            remaining >>= 7
            if remaining != 0 { byte |= 0x80 }
            data.append(byte)
        } while remaining != 0
    }
}

private struct ProtobufReader {
    let data: Data
    var offset = 0

    mutating func nextField() -> (number: Int, wireType: Int)? {
        guard offset < data.count, let key = readVarint() else { return nil }
        return (Int(key >> 3), Int(key & 0x07))
    }

    mutating func readVarint() -> UInt64? {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        while offset < data.count, shift < 64 {
            let byte = data[offset]
            offset += 1
            value |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return value }
            shift += 7
        }
        return nil
    }

    mutating func readLengthDelimited() -> Data? {
        guard let rawLength = readVarint(), rawLength <= UInt64(Int.max) else { return nil }
        let length = Int(rawLength)
        guard length >= 0, offset + length <= data.count else { return nil }
        defer { offset += length }
        return data.subdata(in: offset..<(offset + length))
    }

    mutating func skip(wireType: Int) {
        switch wireType {
        case 0: _ = readVarint()
        case 1: offset = min(data.count, offset + 8)
        case 2:
            if let length = readVarint() { offset = min(data.count, offset + Int(length)) }
        case 5: offset = min(data.count, offset + 4)
        default: offset = data.count
        }
    }
}

private struct BitWriter {
    private var data = Data()
    private var currentByte: UInt8 = 0
    private var bitMask: UInt8 = 0x80

    mutating func append(value: Int, bitCount: Int) {
        guard bitCount > 0 else { return }
        for shift in stride(from: bitCount - 1, through: 0, by: -1) {
            if value & (1 << shift) != 0 { currentByte |= bitMask }
            bitMask >>= 1
            if bitMask == 0 {
                data.append(currentByte)
                currentByte = 0
                bitMask = 0x80
            }
        }
    }

    mutating func finish() -> Data {
        if bitMask != 0x80 { data.append(currentByte) }
        return data
    }
}

private struct BitReader {
    let bytes: [UInt8]
    var bitOffset = 0

    init(data: Data) {
        bytes = [UInt8](data)
    }

    mutating func read(bitCount: Int) -> Int? {
        guard bitCount > 0, bitOffset + bitCount <= bytes.count * 8 else { return nil }
        var value = 0
        for _ in 0..<bitCount {
            let byte = bytes[bitOffset / 8]
            let mask = UInt8(0x80 >> (bitOffset % 8))
            value = (value << 1) | (byte & mask == 0 ? 0 : 1)
            bitOffset += 1
        }
        return value
    }
}

private extension Data {
    func chunked(maximumLength: Int) -> [Data] {
        guard maximumLength > 0, !isEmpty else { return isEmpty ? [] : [self] }
        return stride(from: 0, to: count, by: maximumLength).map { offset in
            subdata(in: offset..<Swift.min(offset + maximumLength, count))
        }
    }
}
