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
            footer: "Etsy #\(order.id)",
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
        let pointsPerMillimeter = 72.0 / 25.4
        var mediaBox = CGRect(
            x: 0,
            y: 0,
            width: format.widthMM * pointsPerMillimeter,
            height: format.heightMM * pointsPerMillimeter
        )

        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw EtsyAddressLabelWriterError.cannotCreateDocument
        }

        context.beginPDFPage(nil)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(mediaBox)
        context.setFillColor(NSColor.black.cgColor)

        let margin = max(9, min(mediaBox.width, mediaBox.height) * 0.055)
        let senderFontSize = max(5.5, min(9, mediaBox.height * 0.07))
        let senderHeight = senderFontSize * 1.65
        drawLine(
            sender.singleLine,
            in: CGRect(
                x: margin,
                y: mediaBox.height - margin - senderHeight,
                width: mediaBox.width - 2 * margin,
                height: senderHeight
            ),
            font: NSFont.systemFont(ofSize: senderFontSize),
            context: context,
            truncate: true
        )

        let separatorY = mediaBox.height - margin - senderHeight - 2
        context.setLineWidth(max(0.5, mediaBox.width / 500))
        context.move(to: CGPoint(x: margin, y: separatorY))
        context.addLine(to: CGPoint(x: mediaBox.width - margin, y: separatorY))
        context.strokePath()

        let footerHeight = footer == nil ? 0 : max(8, mediaBox.height * 0.08)
        let recipientRect = CGRect(
            x: margin,
            y: margin + footerHeight,
            width: mediaBox.width - 2 * margin,
            height: max(20, separatorY - margin - footerHeight - 6)
        )
        drawRecipient(recipient.lines.joined(separator: "\n"), in: recipientRect, context: context)

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
        guard fileManager.fileExists(atPath: url.path),
              let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber,
              size.intValue > 0 else {
            throw EtsyAddressLabelWriterError.cannotCreateDocument
        }
        return url
    }

    private static func drawRecipient(_ text: String, in rect: CGRect, context: CGContext) {
        let upperBound = min(28, max(11, rect.height / 4.8))
        var fontSize = upperBound
        while fontSize > 8 {
            let attributed = recipientText(text, fontSize: fontSize)
            let framesetter = CTFramesetterCreateWithAttributedString(attributed)
            let textLength = CFAttributedStringGetLength(attributed)
            let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
                framesetter,
                CFRange(location: 0, length: textLength),
                nil,
                CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                nil
            )
            if suggested.height <= rect.height && suggested.width <= rect.width + 1 { break }
            fontSize -= 0.5
        }

        let attributed = recipientText(text, fontSize: fontSize)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let textLength = CFAttributedStringGetLength(attributed)
        let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: textLength),
            nil,
            CGSize(width: rect.width, height: rect.height),
            nil
        )
        let verticalOffset = max(0, (rect.height - suggested.height) / 2)
        let textRect = CGRect(x: rect.minX, y: rect.minY + verticalOffset, width: rect.width, height: rect.height - verticalOffset)
        let path = CGPath(rect: textRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: textLength), path, nil)
        CTFrameDraw(frame, context)
    }

    private static func recipientText(_ text: String, fontSize: CGFloat) -> CFAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = fontSize * 0.18
        return NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: NSColor.black,
                .paragraphStyle: paragraph
            ]
        )
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
}
