import Foundation

public enum EtsyOrderCSVError: LocalizedError, Equatable {
    case unreadableFile
    case emptyFile
    case missingAddressColumns
    case noOrders

    public var errorDescription: String? {
        switch self {
        case .unreadableFile: "Die Etsy-CSV-Datei konnte nicht gelesen werden."
        case .emptyFile: "Die Etsy-CSV-Datei ist leer."
        case .missingAddressColumns:
            "Die CSV enthält keine erkennbaren Etsy-Versandadressfelder. Bitte den Etsy-Export „Bestellungen“ verwenden."
        case .noOrders: "In der CSV wurden keine vollständigen Versandadressen gefunden."
        }
    }
}

public enum EtsyOrderCSVParser {
    public static func parse(url: URL) throws -> [EtsyOrder] {
        guard let data = try? Data(contentsOf: url) else { throw EtsyOrderCSVError.unreadableFile }
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .windowsCP1252)
            ?? String(data: data, encoding: .isoLatin1)
        guard let text else { throw EtsyOrderCSVError.unreadableFile }
        return try parse(text: text)
    }

    public static func parse(text: String) throws -> [EtsyOrder] {
        let rows = CSVReader.parse(text)
        guard let header = rows.first, !header.isEmpty else { throw EtsyOrderCSVError.emptyFile }

        let normalizedHeaders = header.map(normalizedKey)
        func index(_ candidates: [String]) -> Int? {
            let keys = Set(candidates.map(normalizedKey))
            return normalizedHeaders.firstIndex(where: keys.contains)
        }

        let orderIndex = index(["Order ID", "Receipt ID", "OrderID", "ReceiptID"])
        let fullNameIndex = index(["Full Name", "Ship Name", "Recipient", "Name"])
        let firstNameIndex = index(["First Name", "Ship First Name"])
        let lastNameIndex = index(["Last Name", "Ship Last Name"])
        let street1Index = index(["Street 1", "Address 1", "Ship Address 1", "Shipping Address 1"])
        let street2Index = index(["Street 2", "Address 2", "Ship Address 2", "Shipping Address 2"])
        let cityIndex = index(["Ship City", "City", "Shipping City"])
        let stateIndex = index(["Ship State", "State", "Province", "Shipping State"])
        let postalIndex = index(["Ship Zipcode", "Ship Postal Code", "Zip", "Zipcode", "Postal Code", "Shipping Postal Code"])
        let countryIndex = index(["Ship Country", "Country", "Shipping Country"])

        guard street1Index != nil, cityIndex != nil, postalIndex != nil,
              fullNameIndex != nil || firstNameIndex != nil || lastNameIndex != nil else {
            throw EtsyOrderCSVError.missingAddressColumns
        }

        func value(_ row: [String], _ position: Int?) -> String {
            guard let position, row.indices.contains(position) else { return "" }
            return row[position].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var orders: [EtsyOrder] = []
        var seen = Set<String>()
        for (rowOffset, row) in rows.dropFirst().enumerated() {
            let name: String
            let fullName = value(row, fullNameIndex)
            if !fullName.isEmpty {
                name = fullName
            } else {
                name = [value(row, firstNameIndex), value(row, lastNameIndex)]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }

            let street1 = value(row, street1Index)
            let city = value(row, cityIndex)
            let postalCode = value(row, postalIndex)
            guard !name.isEmpty, !street1.isEmpty, !city.isEmpty, !postalCode.isEmpty else { continue }

            let exportedID = value(row, orderIndex)
            let identifier = exportedID.isEmpty ? "Zeile-\(rowOffset + 2)" : exportedID
            guard seen.insert(identifier).inserted else { continue }

            orders.append(EtsyOrder(
                id: identifier,
                recipientName: name,
                street1: street1,
                street2: value(row, street2Index),
                city: city,
                state: value(row, stateIndex),
                postalCode: postalCode,
                country: value(row, countryIndex)
            ))
        }

        guard !orders.isEmpty else { throw EtsyOrderCSVError.noOrders }
        return orders
    }

    private static func normalizedKey(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map(String.init)
            .joined()
            .lowercased()
    }
}

private enum CSVReader {
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)
            if insideQuotes {
                if character == "\"" {
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        index = text.index(after: next)
                        continue
                    }
                    insideQuotes = false
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"": insideQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n":
                    row.append(field.trimmingCharacters(in: CharacterSet(charactersIn: "\r")))
                    if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
                    row = []
                    field = ""
                default: field.append(character)
                }
            }
            index = next
        }

        row.append(field.trimmingCharacters(in: CharacterSet(charactersIn: "\r")))
        if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
        return rows
    }
}
