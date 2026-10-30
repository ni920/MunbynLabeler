import Foundation

/// The RW403B-N continuous-stock fix starts with firmware 1.1.49.
/// Missing/malformed device replies never remove the legacy media guard.
public enum MunbynFirmwareCapabilities {
    public static func supportsContinuousStock(_ firmware: String?) -> Bool {
        guard var version = firmware?.trimmingCharacters(in: .whitespacesAndNewlines), !version.isEmpty else { return false }
        if version.first == "v" || version.first == "V" { version.removeFirst() }
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return false }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.utf8.allSatisfy({ (48...57).contains($0) }), let number = Int(part) else { return false }
            numbers.append(number)
        }
        return !numbers.lexicographicallyPrecedes([1, 1, 49])
    }

    public static func canPrint(_ paperType: MunbynPaperType, firmware: String?) -> Bool {
        paperType != .continuous || supportsContinuousStock(firmware)
    }
}
