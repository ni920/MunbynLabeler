import Foundation

public struct LabelFormat: Codable, Equatable, Hashable, Identifiable, Sendable {
    // RW403B print heads use the industry-standard 8 dots/mm grid (marketed as 203 dpi).
    public static let dotsPerMillimeter = 8.0

    public static let shipping100x150 = LabelFormat(
        id: "shipping-100x150",
        name: "Versand 100 × 150 mm",
        widthMM: 100,
        heightMM: 150
    )
    public static let address89x36 = LabelFormat(
        id: "address-89x36",
        name: "Adresse 89 × 36 mm",
        widthMM: 89,
        heightMM: 36
    )
    public static let address70x36 = LabelFormat(
        id: "address-70x36",
        name: "Adresse 70 × 36 mm",
        widthMM: 70,
        heightMM: 36
    )
    public static let product100x50 = LabelFormat(
        id: "product-100x50",
        name: "Breit 100 × 50 mm",
        widthMM: 100,
        heightMM: 50
    )
    public static let square50 = LabelFormat(
        id: "square-50x50",
        name: "Quadratisch 50 × 50 mm",
        widthMM: 50,
        heightMM: 50
    )

    public static let presets: [LabelFormat] = [
        .shipping100x150,
        .address89x36,
        .address70x36,
        .product100x50,
        .square50
    ]

    public static let letterPresets: [LabelFormat] = [
        .address89x36,
        .address70x36,
        .product100x50,
        .square50
    ]

    public static func normalizedLetterFormatID(_ storedID: String?) -> String {
        guard let storedID else { return address89x36.id }
        if storedID == "custom" || letterPresets.contains(where: { $0.id == storedID }) {
            return storedID
        }
        return address89x36.id
    }

    public let id: String
    public let name: String
    public let widthMM: Double
    public let heightMM: Double

    public init(id: String, name: String, widthMM: Double, heightMM: Double) {
        self.id = id
        self.name = name
        self.widthMM = widthMM
        self.heightMM = heightMM
    }

    public static func custom(widthMM: Double, heightMM: Double) -> LabelFormat {
        let width = min(max(widthMM, 20), 108)
        let height = min(max(heightMM, 15), 300)
        return LabelFormat(
            id: "custom",
            name: "Eigenes Format",
            widthMM: width,
            heightMM: height
        )
    }

    public var widthDots: Int {
        max(1, Int((widthMM * Self.dotsPerMillimeter).rounded()))
    }

    public var heightDots: Int {
        max(1, Int((heightMM * Self.dotsPerMillimeter).rounded()))
    }

    public var sizeDescription: String {
        "\(Self.displayMillimeters(widthMM)) × \(Self.displayMillimeters(heightMM)) mm"
    }

    public var technicalDescription: String {
        "\(sizeDescription) · \(widthDots) × \(heightDots) Punkte"
    }

    private static func displayMillimeters(_ value: Double) -> String {
        value.rounded() == value
            ? String(Int(value))
            : String(format: "%.1f", locale: Locale(identifier: "de_DE"), value)
    }
}
