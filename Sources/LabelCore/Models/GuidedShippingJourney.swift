import Foundation

/// Navigation only. Addresses and print state remain in their existing stores.
public struct GuidedShippingJourney: Equatable {
    public enum Task: String, CaseIterable, Identifiable {
        case letter, parcel, postage
        public var id: String { rawValue }
        public var title: String {
            switch self { case .letter: "Brief versenden"; case .parcel: "Paketlabel drucken"; case .postage: "Briefmarken drucken" }
        }
        public var icon: String {
            switch self { case .letter: "envelope"; case .parcel: "shippingbox"; case .postage: "rectangle.stack" }
        }
        public var steps: [Step] {
            switch self {
            case .letter: [.recipient, .franking, .format, .review]
            case .parcel: [.parcelFile, .review]
            case .postage: [.postageSource, .postageSelection, .format, .review]
            }
        }
    }
    public enum Step: String {
        case recipient, franking, format, review, parcelFile, postageSource, postageSelection
        public var title: String {
            switch self {
            case .recipient: "Empfänger"
            case .franking: "Frankierung"
            case .format: "Etikettenformat"
            case .review: "Alles prüfen"
            case .parcelFile: "Paketlabel auswählen"
            case .postageSource: "Briefmarken bereitstellen"
            case .postageSelection: "Briefmarken auswählen"
            }
        }
    }
    public private(set) var task: Task?
    public private(set) var index = 0
    public private(set) var parcelJobID: UUID?
    public init() {}
    public var step: Step? { task.map { $0.steps[index] } }
    public var nextStep: Step? {
        guard let task, index + 1 < task.steps.count else { return nil }
        return task.steps[index + 1]
    }
    public mutating func choose(_ task: Task) {
        self.task = task; index = 0; parcelJobID = nil
    }
    public mutating func advance() {
        guard nextStep != nil else { return }; index += 1
    }
    public mutating func back() {
        if index > 0 { index -= 1 } else { reset() }
    }
    public mutating func goBack(to step: Step) {
        guard let destination = task?.steps.firstIndex(of: step), destination < index else { return }
        index = destination
    }
    public mutating func reset() { task = nil; index = 0; parcelJobID = nil }
    public mutating func receiveParcel(_ id: UUID) {
        choose(.parcel); parcelJobID = id; index = 1
    }
    public mutating func receivePostage() {
        // Importing stock for a letter must not abandon its recipient/step.
        guard task != .letter else { return }
        choose(.postage); index = 1
    }
}
