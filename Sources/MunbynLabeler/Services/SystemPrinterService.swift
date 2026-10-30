import AppKit
import LabelCore

enum SystemPrinterError: LocalizedError {
    case rasterConversionFailed
    case rw403bNotInstalled
    case cancelledOrFailed

    var errorDescription: String? {
        switch self {
        case .rasterConversionFailed:
            "Die Druckdaten konnten nicht für den macOS-Systemdruck vorbereitet werden."
        case .rw403bNotInstalled:
            "Im macOS-System ist kein RW403B eingerichtet. Verbinde den Drucker per USB, füge ihn unter Drucker & Scanner hinzu und stelle im Treiber den Medientyp auf Endlos/Continuous."
        case .cancelledOrFailed:
            "Der Systemdruck wurde abgebrochen oder ist fehlgeschlagen."
        }
    }
}

@MainActor
enum SystemPrinterService {
    static func print(_ raster: LabelRaster, format: LabelFormat) throws {
        guard let printerName = NSPrinter.printerNames.first(where: isRW403BPrinter),
              let printer = NSPrinter(name: printerName) else {
            throw SystemPrinterError.rw403bNotInstalled
        }
        guard let image = LabelPreviewRenderer.image(from: raster) else {
            throw SystemPrinterError.rasterConversionFailed
        }

        let millimetersToPoints = 72.0 / 25.4
        let paperSize = NSSize(
            width: format.widthMM * millimetersToPoints,
            height: format.heightMM * millimetersToPoints
        )
        let printView = RasterPrintView(image: image, frame: NSRect(origin: .zero, size: paperSize))
        let printInfo = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        printInfo.printer = printer
        printInfo.paperSize = paperSize
        printInfo.orientation = .portrait
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true

        let operation = NSPrintOperation(view: printView, printInfo: printInfo)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        guard operation.run() else {
            throw SystemPrinterError.cancelledOrFailed
        }
    }

    private static func isRW403BPrinter(_ name: String) -> Bool {
        let normalized = name.lowercased().replacingOccurrences(of: "-", with: "")
        return normalized.contains("rw403b") || normalized.contains("munbyn")
    }
}

private final class RasterPrintView: NSView {
    private let image: NSImage

    init(image: NSImage, frame: NSRect) {
        self.image = image
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()
        image.draw(
            in: bounds,
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.none]
        )
    }
}
