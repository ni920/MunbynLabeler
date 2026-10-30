import CoreGraphics
import CoreText
import Foundation
import LabelCore
import PDFKit

private func postageFixture(in directory: URL, count: Int) throws -> URL {
    let url = directory.appendingPathComponent("fixture-\(count).pdf")
    var box = CGRect(x: 0, y: 0, width: 595.275, height: 841.889)
    guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else {
        throw SelfTestFailure.assertion("Cannot write postage fixture")
    }
    func text(_ value: String, x: Double, y: Double, size: Double) {
        let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let string = NSAttributedString(string: value, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(CTLineCreateWithAttributedString(string), context)
    }
    for page in 0..<max(1, Int(ceil(Double(count) / 10))) {
        context.beginPDFPage(nil)
        for slot in 0..<min(10, max(0, count - page * 10)) {
            let x = 149.668 + Double(slot % 2) * 255.118
            let y = 720.0 - Double(slot / 2) * 133.228
            text("POST TEST", x: x, y: y + 15, size: 8)
            text("IM 01.01.26 1,80", x: x, y: y, size: 8)
            text("AB 1234 5678", x: x, y: y - 30, size: 7)
            text(String(format: "00 0000 %04X", page * 10 + slot + 1), x: x, y: y - 37, size: 7)
            context.setFillColor(gray: 0, alpha: 1)
            context.fill(CGRect(x: x - 37.7, y: y - 36, width: 31.2, height: 31.2))
        }
        context.endPDFPage()
    }
    context.closePDF()
    return url
}

// PDFKit selection rectangles can include synthesized trailing spaces and text
// from clipped neighbouring source stamps. Measure complete visible glyphs only.
private func visibleTextWidth(_ text: String, on page: PDFPage) throws -> Double {
    let value = (page.string ?? "") as NSString
    var search = NSRange(location: 0, length: value.length)
    while search.length > 0 {
        let range = value.range(of: text, range: search)
        guard range.location != NSNotFound else { break }
        var bounds = CGRect.null
        for index in range.location..<NSMaxRange(range) {
            if value.substring(with: NSRange(location: index, length: 1)).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            bounds = bounds.union(page.characterBounds(at: index))
        }
        if !bounds.isNull && page.bounds(for: .mediaBox).contains(bounds) { return bounds.width }
        let next = NSMaxRange(range)
        search = NSRange(location: next, length: value.length - next)
    }
    throw SelfTestFailure.assertion("No complete visible postage header found")
}

func runPostageTests() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("postage-tests-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let fixture = try postageFixture(in: root, count: 12)
    try runLetterFlowTests(fixture: fixture, directory: root.appendingPathComponent("letter-flows"))
    let stamps = try PostagePDFService.readStamps(from: fixture)
    try require(stamps[0].trackingNumber == "AB123456780000000001", "Tracking number lost leading zeros or its final digit")
    let copyText = PostageStamp.trackingNumbersText(for: Array(stamps.prefix(2)))
    try require(copyText == "AB123456780000000001\nAB123456780000000002", "Tracking copy text must contain complete numbers in stamp order without spaces")
    let unsupportedNumber = PostageStamp(id: "not-a-tracking-number", sourceURL: fixture, pageNumber: 1, number: 0, amount: "", sourceRect: .zero)
    try require(unsupportedNumber.trackingNumber == nil, "Invalid identifiers must not be offered as tracking numbers")
    try require(stamps.count == 12 && Set(stamps.map(\.id)).count == 12, "Multi-page stamp detection lost or duplicated stamps")
    try require(stamps[0].sourceRect.minX < stamps[1].sourceRect.minX, "Stamp order must be row-first")
    try require(stamps[10].pageNumber == 2, "Stamp page number was lost")
    let sizes = stamps.map { $0.sourceRect.size }
    let compact = PostageSheetLayout(stampSizes: sizes, format: .product100x50)
    try require(compact.capacity == 4 && compact.sheets.map(\.count) == [4, 4, 4], "100 x 50 should pack four compact stamps")
    let ten = PostageSheetLayout(stampSizes: Array(sizes.prefix(10)), format: .shipping100x150)
    try require(ten.sheets.count == 1 && ten.sheets[0].count == 10, "Ten stamps should fit on one shipping label")
    for sheet in compact.sheets {
        for (offset, item) in sheet.enumerated() {
            try require(item.rect.size == sizes[item.stampIndex], "Packing changed original stamp size")
            try require(CGRect(origin: .zero, size: compact.paperSize).contains(item.rect), "Stamp extends outside paper")
            for other in sheet.dropFirst(offset + 1) {
                try require(!item.rect.intersects(other.rect), "Packed stamps overlap")
            }
        }
    }
    let noFit = PostageSheetLayout(stampSizes: sizes, format: .custom(widthMM: 20, heightMM: 15))
    try require(noFit.capacity == 0 && noFit.sheets.isEmpty, "Small formats must not shrink postage")
    let outputs = try PostagePDFService.writeSheets(stamps: stamps, format: .product100x50, cutGuides: true, directory: root)
    try require(outputs.count == 3 && Set(outputs.flatMap { $0.1 }) == Set(stamps.map(\.id)), "Generated sheets lost stamp identifiers")
    let header = "IM 01.01.26 1,80"
    let sourcePage = PDFDocument(url: fixture)!.page(at: 0)!
    let sourceWidth = try visibleTextWidth(header, on: sourcePage)
    for output in outputs {
        guard let document = PDFDocument(url: output.0), let page = document.page(at: 0), let value = page.string else {
            throw SelfTestFailure.assertion("Generated stamp sheet cannot be read")
        }
        try require(document.pageCount == 1, "Each print job must contain one label")
        try require(abs(page.bounds(for: .mediaBox).width - 100 * 72 / 25.4) < 0.01, "Output label has the wrong size")
        try require(value.components(separatedBy: header).count - 1 == 4, "Generated label is missing stamp text")
        let width = try visibleTextWidth(header, on: page)
        try require(abs(width - sourceWidth) < 0.01, "PDF composition scaled the postage text")
    }
    // Continuous-stock preparation must preserve original stamp size and identity
    // without needing a printer or firmware handshake.
    let continuousDirectory = root.appendingPathComponent("continuous")
    try FileManager.default.createDirectory(at: continuousDirectory, withIntermediateDirectories: true)
    let continuousOutputs = try PostagePDFService.writeSheets(
        stamps: stamps, format: .continuousLetter100x55, cutGuides: true,
        directory: continuousDirectory)
    try require(Set(continuousOutputs.flatMap { $0.1 }) == Set(stamps.map(\.id)), "Continuous sheets lost or duplicated stamps")
    for output in continuousOutputs {
        let page = PDFDocument(url: output.0)!.page(at: 0)!
        let bounds = page.bounds(for: .mediaBox)
        try require(abs(bounds.width - 100 * 72 / 25.4) < 0.01 && abs(bounds.height - 55 * 72 / 25.4) < 0.01,
                    "Continuous sheet must use the selected 100 × 55 mm cut length")
        let width = try visibleTextWidth(header, on: page)
        try require(abs(width - sourceWidth) < 0.01, "Continuous preparation changed visible text size: source=\(sourceWidth), output=\(width)")
    }
    do {
        _ = try PostagePDFService.readStamps(from: postageFixture(in: root, count: 0))
        throw SelfTestFailure.assertion("Blank PDFs should not be accepted as postage bundles")
    } catch PostagePDFError.unsupportedLayout { }

    try MainActor.assumeIsolated {
        let libraryDirectory = root.appendingPathComponent("library")
        let library = PostageStampStore(directory: libraryDirectory)
        let ids = try library.importBundle(fixture)
        try require(library.canPrint(ids), "Imported stamps should be selectable")
        try require(library.update(Array(ids.prefix(4)), status: .printing), "Print reservation was not saved")
        let resumed = PostageStampStore(directory: libraryDirectory)
        try require(resumed.entries[0].stamp.trackingNumber == stamps[0].trackingNumber, "Tracking number changed after restoring the existing library")
        try require(resumed.entries.prefix(4).allSatisfy { $0.status == .checkPrint }, "Interrupted prints must require review")
        try require(!resumed.canPrint([ids[0]]), "Interrupted stamp was offered for automatic reprinting")
        _ = resumed.update(Array(ids.prefix(4)), status: .printed)
        _ = try resumed.importBundle(fixture)
        try require(resumed.entries.count == 12 && resumed.entries[0].status == .printed, "Reimport reset the printed stamp history")
        try Data("broken history".utf8).write(to: libraryDirectory.appendingPathComponent("bestand.json"))
        let damaged = PostageStampStore(directory: libraryDirectory)
        try require(damaged.storageError != nil && !damaged.canPrint(ids), "Unreadable stamp history must block printing")
    }

    if let option = CommandLine.arguments.firstIndex(of: "--postage-pdf"), CommandLine.arguments.indices.contains(option + 1) {
        let url = URL(fileURLWithPath: CommandLine.arguments[option + 1])
        let real = try PostagePDFService.readStamps(from: url)
        let inspection = FileManager.default.temporaryDirectory.appendingPathComponent("munbyn-postage-preview")
        try FileManager.default.createDirectory(at: inspection, withIntermediateDirectories: true)
        for format in [LabelFormat.shipping100x150, .product100x50] {
            let files = try PostagePDFService.writeSheets(stamps: real, format: format, cutGuides: true, directory: inspection)
            print("Postage integration: \(real.count) stamps -> \(files.count) labels (\(format.sizeDescription))")
            for file in files { print("Preview: \(file.0.path)") }
        }
    }
    print("Postage tests passed: packing, original size, PDF composition, deduplication, print recovery and history persistence")
}
