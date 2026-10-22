import CoreGraphics
import Foundation

public struct PDFLabelPlacement: Equatable, Sendable {
    public enum Rotation: Equatable, Sendable {
        case none
        case clockwise90
    }

    public let sourceRect: CGRect
    public let rotation: Rotation

    public init(sourceRect: CGRect, rotation: Rotation) {
        self.sourceRect = sourceRect
        self.rotation = rotation
    }

    public static func resolve(pageBounds: CGRect, labelFormat: LabelFormat) -> PDFLabelPlacement {
        guard labelFormat == .shipping100x150, isA4Portrait(pageBounds) else {
            return PDFLabelPlacement(sourceRect: pageBounds, rotation: .none)
        }

        // DHL's downloadable A4 Paketmarke places the actual shipping label in
        // the upper half and a non-printable receipt in the lower half. Leave a
        // small inset at the separator so the scissors and cut line are omitted.
        let separatorInset: CGFloat = 12
        let halfHeight = pageBounds.height / 2
        return PDFLabelPlacement(
            sourceRect: CGRect(
                x: pageBounds.minX,
                y: pageBounds.minY + halfHeight + separatorInset,
                width: pageBounds.width,
                height: halfHeight - separatorInset
            ),
            rotation: .clockwise90
        )
    }

    public func drawingTransform(in destination: CGRect) -> CGAffineTransform {
        guard sourceRect.width > 0, sourceRect.height > 0 else { return .identity }

        let orientedSize = rotation == .clockwise90
            ? CGSize(width: sourceRect.height, height: sourceRect.width)
            : sourceRect.size
        let target = Self.aspectFit(orientedSize, in: destination)

        switch rotation {
        case .none:
            let scaleX = target.width / sourceRect.width
            let scaleY = target.height / sourceRect.height
            return CGAffineTransform(
                a: scaleX,
                b: 0,
                c: 0,
                d: scaleY,
                tx: target.minX - sourceRect.minX * scaleX,
                ty: target.minY - sourceRect.minY * scaleY
            )
        case .clockwise90:
            let scaleX = target.width / sourceRect.height
            let scaleY = target.height / sourceRect.width
            return CGAffineTransform(
                a: 0,
                b: -scaleY,
                c: scaleX,
                d: 0,
                tx: target.minX - sourceRect.minY * scaleX,
                ty: target.minY + (sourceRect.minX + sourceRect.width) * scaleY
            )
        }
    }

    private static func isA4Portrait(_ rect: CGRect) -> Bool {
        let a4Width: CGFloat = 595.28
        let a4Height: CGFloat = 841.89
        let tolerance: CGFloat = 8
        return abs(rect.width - a4Width) <= tolerance
            && abs(rect.height - a4Height) <= tolerance
    }

    private static func aspectFit(_ source: CGSize, in destination: CGRect) -> CGRect {
        let scale = min(destination.width / source.width, destination.height / source.height)
        let size = CGSize(width: source.width * scale, height: source.height * scale)
        return CGRect(
            x: destination.midX - size.width / 2,
            y: destination.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
