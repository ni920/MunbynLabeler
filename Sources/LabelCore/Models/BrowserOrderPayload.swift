import Foundation

public struct BrowserOrderPayload: Codable, Equatable, Sendable {
    public let version: Int
    public let orderID: String
    public let recipient: RecipientAddress
    public let sourceURL: String?

    public init(
        version: Int = 1,
        orderID: String,
        recipient: RecipientAddress,
        sourceURL: String? = nil
    ) {
        self.version = version
        self.orderID = orderID
        self.recipient = recipient
        self.sourceURL = sourceURL
    }
}

public enum BrowserOrderLinkError: LocalizedError, Equatable {
    case invalidURL
    case payloadMissing
    case payloadTooLarge
    case unsupportedVersion(Int)
    case invalidPayload

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "Dieser Link gehört nicht zu Munbyn Labeler."
        case .payloadMissing: "Der Etsy-Link enthält keine Bestelldaten."
        case .payloadTooLarge: "Die Etsy-Bestelldaten sind zu groß."
        case .unsupportedVersion(let version): "Die Etsy-Erweiterung verwendet die nicht unterstützte Version \(version)."
        case .invalidPayload: "Die Etsy-Bestelldaten konnten nicht gelesen werden."
        }
    }
}

public enum BrowserOrderLink {
    public static let scheme = "munbyn-labeler"
    public static let host = "etsy-order"
    private static let maximumPayloadBytes = 64 * 1_024

    public static func makeURL(for payload: BrowserOrderPayload) throws -> URL {
        let data = try JSONEncoder().encode(payload)
        guard data.count <= maximumPayloadBytes else { throw BrowserOrderLinkError.payloadTooLarge }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: "payload", value: base64URLEncoded(data))]
        guard let url = components.url else { throw BrowserOrderLinkError.invalidURL }
        return url
    }

    public static func decode(_ url: URL) throws -> BrowserOrderPayload {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw BrowserOrderLinkError.invalidURL
        }
        guard let encoded = components.queryItems?.first(where: { $0.name == "payload" })?.value,
              !encoded.isEmpty else {
            throw BrowserOrderLinkError.payloadMissing
        }
        guard let data = base64URLDecoded(encoded), data.count <= maximumPayloadBytes else {
            throw BrowserOrderLinkError.invalidPayload
        }

        let payload: BrowserOrderPayload
        do {
            payload = try JSONDecoder().decode(BrowserOrderPayload.self, from: data)
        } catch {
            throw BrowserOrderLinkError.invalidPayload
        }
        guard payload.version == 1 else {
            throw BrowserOrderLinkError.unsupportedVersion(payload.version)
        }
        return payload
    }

    private static func base64URLEncoded(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecoded(_ value: String) -> Data? {
        var normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder != 0 {
            normalized += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: normalized)
    }
}
