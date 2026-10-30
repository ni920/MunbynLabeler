import Combine
import Foundation

@MainActor
public final class LetterFlowStore: ObservableObject {
    @Published public private(set) var flows: [LetterShipmentFlow] = []
    @Published public private(set) var storageError: String?
    private let url: URL

    public init(directory: URL? = nil) {
        let directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MunbynLabeler/Briefversand", isDirectory: true)
        url = directory.appendingPathComponent("versand.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            flows = try JSONDecoder().decode([LetterShipmentFlow].self, from: Data(contentsOf: url)).map { flow in
                var restored = flow
                if restored.stage == .printingAddress {
                    restored.stage = .addressCheck
                    restored.errorMessage = "Der vorherige Adressdruck wurde nicht bestätigt. Bitte den Ausdruck prüfen."
                } else if restored.stage == .printingStamp {
                    restored.stage = .stampCheck
                    restored.errorMessage = "Der vorherige Briefmarkendruck wurde nicht bestätigt. Bitte den Ausdruck prüfen."
                }
                return restored
            }
        } catch { storageError = "Die Briefversand-Historie konnte nicht gelesen werden: \(error.localizedDescription)" }
    }

    public func flow(_ id: UUID) -> LetterShipmentFlow? { flows.first { $0.id == id } }

    public func add(_ flow: LetterShipmentFlow) throws {
        if let storageError { throw NSError(domain: "Briefversand", code: 1, userInfo: [NSLocalizedDescriptionKey: storageError]) }
        var updated = flows
        updated.insert(flow, at: 0)
        try save(updated)
        flows = updated
    }

    @discardableResult
    public func update(_ id: UUID, stage: LetterShipmentFlow.Stage, error: String? = nil) -> Bool {
        guard storageError == nil, let index = flows.firstIndex(where: { $0.id == id }) else { return false }
        var updated = flows
        updated[index].stage = stage; updated[index].errorMessage = error
        do { try save(updated); flows = updated; return true }
        catch { storageError = "Der Briefversand-Status konnte nicht gespeichert werden: \(error.localizedDescription)"; return false }
    }

    private func save(_ records: [LetterShipmentFlow]) throws {
        try JSONEncoder().encode(records).write(to: url, options: .atomic)
    }
}
