import Foundation

public struct EtsyOrder: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let recipientName: String
    public let street1: String
    public let street2: String
    public let city: String
    public let state: String
    public let postalCode: String
    public let country: String

    public init(
        id: String,
        recipientName: String,
        street1: String,
        street2: String = "",
        city: String,
        state: String = "",
        postalCode: String,
        country: String
    ) {
        self.id = id
        self.recipientName = recipientName
        self.street1 = street1
        self.street2 = street2
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
    }

    public var recipientLines: [String] {
        var lines = [recipientName, street1]
        if !street2.isEmpty { lines.append(street2) }
        let locality = [postalCode, city].filter { !$0.isEmpty }.joined(separator: " ")
        if !locality.isEmpty { lines.append(locality) }
        if !state.isEmpty, !lines.contains(state) { lines.append(state) }
        if !country.isEmpty { lines.append(country) }
        return lines
    }
}

public struct SenderAddress: Codable, Equatable, Sendable {
    public let name: String
    public let street: String
    public let postalCode: String
    public let city: String
    public let country: String

    public init(name: String, street: String, postalCode: String, city: String, country: String) {
        self.name = name
        self.street = street
        self.postalCode = postalCode
        self.city = city
        self.country = country
    }

    public var isComplete: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var singleLine: String {
        [name, street, "\(postalCode) \(city)", country]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
