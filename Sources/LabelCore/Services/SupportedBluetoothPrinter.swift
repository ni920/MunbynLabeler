import Foundation

public enum SupportedBluetoothPrinter {
    public static let modelName = "RW403B"

    public static func matches(name: String) -> Bool {
        let normalized = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        return normalized.hasPrefix(modelName)
            || (normalized.hasPrefix("MUNBYN") && normalized.contains(modelName))
    }
}
