import Foundation

public struct LetterShipmentFlow: Identifiable, Codable, Equatable, Sendable {
    public enum Stage: String, Codable, Sendable {
        case ready, printingAddress, addressPrinted, printingStamp, completed, addressCheck, stampCheck
        public var title: String {
            switch self {
            case .ready: "Bereit"
            case .printingAddress: "1/2 · Adresse wird gedruckt"
            case .addressPrinted: "Adresse gedruckt · Briefmarke ausstehend"
            case .printingStamp: "2/2 · Briefmarke wird gedruckt"
            case .completed: "Adresse und Briefmarke gedruckt"
            case .addressCheck: "Adressausdruck prüfen"
            case .stampCheck: "Briefmarkenausdruck prüfen"
            }
        }
    }
    public let id: UUID
    public let createdAt: Date
    public let recipientName: String
    public let orderID: String?
    public let stamp: PostageStamp
    public let addressJob: PrintJob
    public let stampJob: PrintJob
    public var stage: Stage
    public var errorMessage: String?

    public init(id: UUID, recipientName: String, orderID: String?, stamp: PostageStamp,
                addressJob: PrintJob, stampJob: PrintJob, createdAt: Date = Date(), stage: Stage = .ready) {
        self.id = id; self.createdAt = createdAt; self.recipientName = recipientName; self.orderID = orderID
        self.stamp = stamp; self.addressJob = addressJob; self.stampJob = stampJob; self.stage = stage
    }
}
