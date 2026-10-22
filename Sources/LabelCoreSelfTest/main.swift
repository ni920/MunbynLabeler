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

func readVarint(_ data: Data, offset: inout Int) -> UInt64? {
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

func protobufBytesField(_ number: Int, in data: Data) -> Data? {
    var offset = 0
    while offset < data.count, let key = readVarint(data, offset: &offset) {
        let field = Int(key >> 3)
        let wire = Int(key & 0x07)
        if wire == 0 {
            _ = readVarint(data, offset: &offset)
        } else if wire == 2, let rawLength = readVarint(data, offset: &offset) {
            let length = Int(rawLength)
            guard offset + length <= data.count else { return nil }
            let value = data.subdata(in: offset..<(offset + length))
            offset += length
            if field == number { return value }
        } else {
            return nil
        }
    }
    return nil
}

func protobufVarintField(_ number: Int, in data: Data) -> UInt64? {
    var offset = 0
    while offset < data.count, let key = readVarint(data, offset: &offset) {
        let field = Int(key >> 3)
        let wire = Int(key & 0x07)
        if wire == 0, let value = readVarint(data, offset: &offset) {
            if field == number { return value }
        } else if wire == 2, let rawLength = readVarint(data, offset: &offset) {
            offset += Int(rawLength)
            guard offset <= data.count else { return nil }
        } else {
            return nil
        }
    }
    return nil
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

    let heatshrinkInput = Data([65, 66, 65, 66, 65, 66])
    let compressed = HeatshrinkCodec.compress(heatshrinkInput)
    try require(compressed == Data([0xA0, 0xD0, 0x80, 0x04, 0xC0]), "Heatshrink wire format differs from RW403B")
    try require(HeatshrinkCodec.decompress(compressed) == heatshrinkInput, "Heatshrink round trip failed")

    var frameDecoder = MunbynFrameDecoder()
    let selfTestFrame = MunbynRW403BProtocol.selfTestFrame()
    let selfTestPayloads = frameDecoder.append(selfTestFrame)
    try require(selfTestPayloads == [Data([0x08, 0x02])], "RW403B self-test frame is invalid")

    let sections = MunbynRW403BProtocol.printSections(raster: raster, maximumImageChunkLength: 40)
    try require(!sections.isEmpty, "RW403B raster produced no sections")
    try require(sections.allSatisfy { !$0.frames.isEmpty }, "RW403B raster section has no frames")
    var printFrameDecoder = MunbynFrameDecoder()
    let printPayloads = printFrameDecoder.append(sections[0].frames[0])
    try require(printPayloads.count == 1, "RW403B print frame is invalid")
    let printMessage = protobufBytesField(5, in: printPayloads[0])
    try require(
        printMessage.flatMap { protobufVarintField(6, in: $0) } == 2,
        "RW403B print width must be millimetres, not dot width"
    )
    let completedPrintReport = Data([0x08, 0x06, 0x1A, 0x05, 0x08, 0x0A, 0x12, 0x01, 0x30])
    try require(
        MunbynRW403BProtocol.parseResponse(completedPrintReport) == .printStatus("0"),
        "RW403B completed-print report was not recognized"
    )

    let addressFormat = LabelFormat.address89x36
    try require(addressFormat.widthDots == 712, "89 mm label width has wrong 8 dots/mm conversion")
    try require(addressFormat.heightDots == 288, "36 mm label height has wrong 203 dpi conversion")
    try require(!LabelFormat.letterPresets.contains(.shipping100x150), "Shipping format leaked into letter presets")
    try require(LabelFormat.letterPresets.first == .address89x36, "Default letter preset is not 89 × 36 mm")
    try require(
        LabelFormat.normalizedLetterFormatID(LabelFormat.shipping100x150.id) == LabelFormat.address89x36.id,
        "Legacy 100 × 150 mm letter format was not migrated"
    )
    let clampedFormat = LabelFormat.custom(widthMM: 500, heightMM: 2)
    try require(clampedFormat.widthMM == 108 && clampedFormat.heightMM == 15, "Custom label bounds failed")

    let a4Bounds = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
    let dhlPlacement = PDFLabelPlacement.resolve(pageBounds: a4Bounds, labelFormat: .shipping100x150)
    try require(dhlPlacement.rotation == .clockwise90, "DHL A4 label is not rotated into portrait format")
    try require(dhlPlacement.sourceRect.minY > a4Bounds.midY, "DHL receipt was not excluded from the crop")
    try require(dhlPlacement.sourceRect.maxY == a4Bounds.maxY, "DHL label crop does not reach the page top")
    let directLabelBounds = CGRect(x: 0, y: 0, width: 283.46, height: 425.2)
    let directPlacement = PDFLabelPlacement.resolve(pageBounds: directLabelBounds, labelFormat: .shipping100x150)
    try require(directPlacement == PDFLabelPlacement(sourceRect: directLabelBounds, rotation: .none), "Direct 100 × 150 PDF was changed")

    let csv = """
    Sale Date,Order ID,Full Name,Street 1,Street 2,Ship City,Ship State,Ship Zipcode,Ship Country
    10/22/26,12345,"Mia Muster","Hauptstraße 1","Wohnung 2",Saarlouis,Saarland,66740,Germany
    10/22/26,12346,"John Smith","12 Market Street, South",,London,,SW1A 1AA,United Kingdom
    """
    let etsyOrders = try EtsyOrderCSVParser.parse(text: csv)
    try require(etsyOrders.count == 2, "Etsy CSV order count is wrong")
    try require(etsyOrders[0].recipientName == "Mia Muster", "Etsy recipient name was not parsed")
    try require(etsyOrders[1].street1 == "12 Market Street, South", "Quoted Etsy address was not parsed")
    try require(etsyOrders[0].recipientLines.contains("66740 Saarlouis"), "Etsy locality formatting failed")
    try require(etsyOrders[0].recipientAddress.isComplete, "Imported recipient address should be complete")
    try require(etsyOrders[0].recipientAddress.lines.first == "Mia Muster", "Recipient address lines are wrong")

    let incompleteRecipient = RecipientAddress(
        name: "",
        street1: "Hauptstraße 1",
        postalCode: "66740",
        city: "Saarlouis",
        country: "Deutschland"
    )
    try require(!incompleteRecipient.isComplete, "Incomplete recipient address was accepted")

    let browserOrder = BrowserOrderPayload(
        orderID: "987654321",
        recipient: etsyOrders[0].recipientAddress,
        sourceURL: "https://www.etsy.com/your/orders/987654321"
    )
    let browserURL = try BrowserOrderLink.makeURL(for: browserOrder)
    try require(browserURL.scheme == "munbyn-labeler", "Browser order URL scheme is wrong")
    let decodedBrowserOrder = try BrowserOrderLink.decode(browserURL)
    try require(decodedBrowserOrder == browserOrder, "Browser order URL round trip failed")
    try require(decodedBrowserOrder.recipient.name == "Mia Muster", "Browser recipient was not preserved")
    try require(decodedBrowserOrder.sourceURL == browserOrder.sourceURL, "Browser source URL was not preserved")

    let legacyJobJSON = """
    {"id":"00000000-0000-0000-0000-000000000001","sourceURL":"file:///tmp/label.pdf","sourceFingerprint":"legacy","createdAt":0,"status":"ready"}
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let legacyJob = try decoder.decode(PrintJob.self, from: Data(legacyJobJSON.utf8))
    try require(legacyJob.resolvedLabelFormat == .shipping100x150, "Legacy print job format fallback failed")

    print("LabelCoreSelfTest: 38 checks passed")
} catch {
    fputs("LabelCoreSelfTest failed: \(error)\n", stderr)
    exit(1)
}
