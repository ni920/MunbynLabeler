import AppKit
import CoreText
import Foundation
import LabelCore

enum EtsyAddressLabelWriterError: LocalizedError {
    case cannotCreateDirectory
    case cannotCreateDocument

    var errorDescription: String? {
        switch self {
        case .cannotCreateDirectory: "Der Ordner für Adressetiketten konnte nicht erstellt werden."
        case .cannotCreateDocument: "Das Adressetikett konnte nicht erzeugt werden."
        }
    }
}

enum EtsyAddressLabelWriter {
    static func write(
        order: EtsyOrder,
        sender: SenderAddress,
        format: LabelFormat,
        fileManager: FileManager = .default
    ) throws -> URL {
        try write(
            recipient: order.recipientAddress,
            sender: sender,
            format: format,
            filenamePrefix: "Etsy-\(order.id)",
            footer: nil,
            fileManager: fileManager
        )
    }

    static func write(
        recipient: RecipientAddress,
        sender: SenderAddress,
        format: LabelFormat,
        fileManager: FileManager = .default
    ) throws -> URL {
        try write(
            recipient: recipient,
            sender: sender,
            format: format,
            filenamePrefix: "Adresse-\(UUID().uuidString)",
            footer: nil,
            fileManager: fileManager
        )
    }

    private static func write(
        recipient: RecipientAddress,
        sender: SenderAddress,
        format: LabelFormat,
        filenamePrefix: String,
        footer: String?,
        fileManager: FileManager
    ) throws -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base
            .appendingPathComponent("MunbynLabeler", isDirectory: true)
            .appendingPathComponent("Address Labels", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw EtsyAddressLabelWriterError.cannotCreateDirectory
        }

        let safePrefix = sanitizedFilename(filenamePrefix)
        let safeName = sanitizedFilename(recipient.name)
        let url = directory.appendingPathComponent("\(safePrefix)-\(safeName).pdf")
        let pdf = try makePDFData(
            recipient: recipient,
            sender: sender,
            format: format,
            footer: footer
        )
        do {
            try pdf.write(to: url, options: .atomic)
        } catch {
            throw EtsyAddressLabelWriterError.cannotCreateDocument
        }

        guard fileManager.fileExists(atPath: url.path),
              let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber,
              size.intValue > 0 else {
            throw EtsyAddressLabelWriterError.cannotCreateDocument
        }
        return url
    }

    static func makePDFData(
        recipient: RecipientAddress,
        sender: SenderAddress,
        format: LabelFormat,
        footer: String? = nil
    ) throws -> Data {
        let pointsPerMillimeter = 72.0 / 25.4
        var mediaBox = CGRect(
            x: 0,
            y: 0,
            width: format.widthMM * pointsPerMillimeter,
            height: format.heightMM * pointsPerMillimeter
        )
        let data = NSMutableData()

        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw EtsyAddressLabelWriterError.cannotCreateDocument
        }

        context.beginPDFPage(nil)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(mediaBox)
        context.setFillColor(NSColor.black.cgColor)

        let margin = max(9, min(mediaBox.width, mediaBox.height) * 0.055)
        let senderFontSize = max(5.5, min(9, mediaBox.height * 0.07))
        let senderHeight = senderFontSize * 1.65
        drawFittedLine(
            senderLine(sender),
            in: CGRect(
                x: margin,
                y: mediaBox.height - margin - senderHeight,
                width: mediaBox.width - 2 * margin,
                height: senderHeight
            ),
            maximumFontSize: senderFontSize,
            minimumFontSize: 5.0,
            context: context
        )

        let separatorY = mediaBox.height - margin - senderHeight - 4

        let footerHeight = footer == nil ? 0 : max(8, mediaBox.height * 0.08)
        let recipientRect = CGRect(
            x: margin,
            y: margin + footerHeight,
            width: mediaBox.width - 2 * margin,
            height: max(20, separatorY - margin - footerHeight - 6)
        )
        drawRecipient(recipientLines(recipient), in: recipientRect, context: context)

        if let footer {
            drawLine(
                footer,
                in: CGRect(x: margin, y: margin, width: mediaBox.width - 2 * margin, height: footerHeight),
                font: NSFont.systemFont(ofSize: max(5.5, min(8, footerHeight * 0.65))),
                context: context,
                alignment: .right,
                truncate: true
            )
        }

        context.endPDFPage()
        context.closePDF()
        guard data.length > 0 else {
            throw EtsyAddressLabelWriterError.cannotCreateDocument
        }
        return data as Data
    }

    private static func drawRecipient(_ lines: [String], in rect: CGRect, context: CGContext) {
        let upperBound = min(18, max(9.5, min(rect.width / 19, rect.height / 5.2)))
        var fontSize = upperBound
        while fontSize > 8.5 {
            let attributed = recipientText(lines, fontSize: fontSize)
            let framesetter = CTFramesetterCreateWithAttributedString(attributed)
            let textLength = CFAttributedStringGetLength(attributed)
            let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
                framesetter,
                CFRange(location: 0, length: textLength),
                nil,
                CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                nil
            )
            if suggested.height <= rect.height && widestLine(lines, fontSize: fontSize) <= rect.width { break }
            fontSize -= 0.5
        }

        let attributed = recipientText(lines, fontSize: fontSize)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let textLength = CFAttributedStringGetLength(attributed)
        let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: textLength),
            nil,
            CGSize(width: rect.width, height: rect.height),
            nil
        )
        let textHeight = min(rect.height, suggested.height + fontSize * 0.2)
        let textRect = CGRect(
            x: rect.minX,
            y: rect.minY + max(0, (rect.height - textHeight) / 2),
            width: rect.width,
            height: textHeight
        )
        let path = CGPath(rect: textRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: textLength), path, nil)
        CTFrameDraw(frame, context)
    }

    private static func recipientText(_ lines: [String], fontSize: CGFloat) -> CFAttributedString {
        let text = lines.joined(separator: "\n")
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = fontSize * 0.12
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: NSColor.black,
                .paragraphStyle: paragraph
            ]
        )
        if let firstLine = lines.first, !firstLine.isEmpty {
            attributed.addAttribute(
                .font,
                value: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                range: NSRange(location: 0, length: (firstLine as NSString).length)
            )
        }
        return attributed
    }

    private static func widestLine(_ lines: [String], fontSize: CGFloat) -> CGFloat {
        lines.enumerated().map { index, line in
            let font = NSFont.systemFont(ofSize: fontSize, weight: index == 0 ? .semibold : .medium)
            let attributed = NSAttributedString(string: line, attributes: [.font: font])
            return CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributed), nil, nil, nil))
        }.max() ?? 0
    }

    private static func drawFittedLine(
        _ text: String,
        in rect: CGRect,
        maximumFontSize: CGFloat,
        minimumFontSize: CGFloat,
        context: CGContext
    ) {
        var fontSize = maximumFontSize
        while fontSize > minimumFontSize {
            let font = NSFont.systemFont(ofSize: fontSize)
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
            if CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) <= rect.width { break }
            fontSize -= 0.25
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byClipping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        context.textPosition = CGPoint(x: rect.minX, y: rect.midY - (ascent + descent) / 2)
        CTLineDraw(line, context)
    }

    private static func drawLine(
        _ text: String,
        in rect: CGRect,
        font: NSFont,
        context: CGContext,
        alignment: NSTextAlignment = .left,
        truncate: Bool = false
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = truncate ? .byTruncatingTail : .byWordWrapping
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.black,
                .paragraphStyle: paragraph
            ]
        )
        let line = CTLineCreateWithAttributedString(attributed)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        let y = rect.midY - (ascent + descent) / 2
        context.textPosition = CGPoint(x: rect.minX, y: y)
        if alignment == .right {
            let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            context.textPosition.x = max(rect.minX, rect.maxX - width)
        }
        CTLineDraw(line, context)
    }

    private static func sanitizedFilename(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let value = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        return String(value).replacingOccurrences(of: "--", with: "-").prefix(60).description
    }

    private static func recipientLines(_ recipient: RecipientAddress) -> [String] {
        var lines = [recipient.name, recipient.street1]
        if !recipient.street2.isEmpty { lines.append(recipient.street2) }
        let locality = [recipient.postalCode, recipient.city]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !locality.isEmpty { lines.append(locality) }
        if !recipient.state.isEmpty, !lines.contains(recipient.state) { lines.append(recipient.state) }
        if !recipient.country.isEmpty, !isGermany(recipient.country) {
            lines.append(recipient.country.uppercased(with: Locale(identifier: "de_DE")))
        }
        return lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func senderLine(_ sender: SenderAddress) -> String {
        var parts = [sender.name, sender.street, "\(sender.postalCode) \(sender.city)"]
        if !sender.country.isEmpty, !isGermany(sender.country) { parts.append(sender.country) }
        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private static func isGermany(_ value: String) -> Bool {
        let normalized = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()
            .filter { $0.isLetter }
        return ["de", "deutschland", "germany", "bundesrepublikdeutschland"].contains(normalized)
    }
}
