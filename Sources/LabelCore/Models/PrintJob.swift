import Foundation

public struct PrintJob: Identifiable, Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable {
        case ready
        case printing
        case printed
        case failed

        public var label: String {
            switch self {
            case .ready: "Bereit"
            case .printing: "Wird gedruckt"
            case .printed: "Gedruckt"
            case .failed: "Fehlgeschlagen"
            }
        }
    }

    public let id: UUID
    public let sourceURL: URL
    public let sourceFingerprint: String
    public let createdAt: Date
    public var status: Status
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        sourceFingerprint: String,
        createdAt: Date = Date(),
        status: Status = .ready,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.sourceFingerprint = sourceFingerprint
        self.createdAt = createdAt
        self.status = status
        self.errorMessage = errorMessage
    }
}
