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
    public let labelFormat: LabelFormat?
    public let displayName: String?
    public let postageStampIDs: [String]?
    public let letterFlowID: UUID?
    public var status: Status
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        sourceFingerprint: String,
        createdAt: Date = Date(),
        labelFormat: LabelFormat? = nil,
        displayName: String? = nil,
        postageStampIDs: [String]? = nil,
        letterFlowID: UUID? = nil,
        status: Status = .ready,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.sourceFingerprint = sourceFingerprint
        self.createdAt = createdAt
        self.labelFormat = labelFormat
        self.displayName = displayName
        self.postageStampIDs = postageStampIDs
        self.letterFlowID = letterFlowID
        self.status = status
        self.errorMessage = errorMessage
    }

    public var resolvedLabelFormat: LabelFormat {
        labelFormat ?? .shipping100x150
    }

    public var title: String {
        displayName ?? sourceURL.lastPathComponent
    }
}
