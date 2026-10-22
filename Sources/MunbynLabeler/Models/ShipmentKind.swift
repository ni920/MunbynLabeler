import Foundation

enum ShipmentKind: String, CaseIterable, Identifiable {
    case letter
    case parcel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .letter: "Brief"
        case .parcel: "Paket"
        }
    }

    var icon: String {
        switch self {
        case .letter: "envelope"
        case .parcel: "shippingbox"
        }
    }
}
