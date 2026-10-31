import Foundation
import Combine
import CryptoKit

@MainActor
public final class PostageStampStore: ObservableObject {
    public enum Status: String, Codable {
        case available, reserved, printing, printed, checkPrint
        public var title: String {
            switch self {
            case .available: "Verfügbar"
            case .reserved: "Für Brief reserviert"
            case .printing: "Wird gedruckt"
            case .printed: "Gedruckt"
            case .checkPrint: "Ausdruck prüfen"
            }
        }
    }
    public struct Entry: Identifiable, Codable {
        public var stamp: PostageStamp
        public var status: Status = .available
        public var reservationID: UUID?
        /// Optional so libraries saved by older versions keep loading.
        public var printedAt: Date?
        public var printCount: Int?
        public var releasedAt: Date?
        public var id: String { stamp.id }
        public var isUsed: Bool { status == .printed || status == .checkPrint || status == .printing }

        public init(stamp: PostageStamp, status: Status = .available, reservationID: UUID? = nil,
                    printedAt: Date? = nil, printCount: Int? = nil, releasedAt: Date? = nil) {
            self.stamp = stamp; self.status = status; self.reservationID = reservationID
            self.printedAt = printedAt; self.printCount = printCount; self.releasedAt = releasedAt
        }
    }
    @Published public private(set) var entries: [Entry] = []
    @Published public private(set) var storageError: String?
    public let directory: URL
    private let persistenceURL: URL

    public init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MunbynLabeler/Briefmarken", isDirectory: true)
        persistenceURL = self.directory.appendingPathComponent("bestand.json")
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: persistenceURL.path) {
          do {
            let data = try Data(contentsOf: persistenceURL)
            let loaded = try JSONDecoder().decode([Entry].self, from: data)
            entries = loaded.map { entry in
                var restored = entry
                if restored.status == .printing { restored.status = .checkPrint }
                return restored
            }
          } catch { storageError = "Der gespeicherte Briefmarkenbestand konnte nicht gelesen werden. Druck ist gesperrt, damit bereits gedruckte Marken nicht erneut verwendet werden." }
        }
    }

    @discardableResult
    public func importBundle(_ url: URL) throws -> [String] {
        if let storageError { throw NSError(domain: "Briefmarken", code: 1, userInfo: [NSLocalizedDescriptionKey: storageError]) }
        let scope = url.startAccessingSecurityScopedResource()
        defer { if scope { url.stopAccessingSecurityScopedResource() } }
        let fingerprint = SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
        let cached = directory.appendingPathComponent("\(fingerprint).pdf")
        // Parse before accepting a file into the library.
        _ = try PostagePDFService.readStamps(from: url)
        if !FileManager.default.fileExists(atPath: cached.path) { try FileManager.default.copyItem(at: url, to: cached) }
        let stamps = try PostagePDFService.readStamps(from: cached)
        let existing = Set(entries.map(\.id))
        let additions = stamps.filter { !existing.contains($0.id) }
        let updated = entries + additions.map { Entry(stamp: $0) }
        try persist(updated)
        entries = updated
        return stamps.map(\.id)
    }

    public func canPrint(_ ids: [String], reservationID: UUID? = nil) -> Bool {
        storageError == nil && !ids.isEmpty && Set(ids).count == ids.count && ids.allSatisfy { id in
            entries.contains {
                $0.id == id && ($0.status == .available ||
                    ($0.status == .reserved && reservationID != nil && $0.reservationID == reservationID))
            }
        }
    }

    @discardableResult
    public func reserve(_ id: String, for owner: UUID, afterReview: Bool = false) -> Bool {
        guard storageError == nil, let index = entries.firstIndex(where: { $0.id == id }) else { return false }
        let entry = entries[index]
        guard entry.status == .available ||
                (entry.status == .reserved && entry.reservationID == owner) ||
                (afterReview && entry.status == .checkPrint && entry.reservationID == owner) else { return false }
        var updated = entries
        updated[index].status = .reserved
        updated[index].reservationID = owner
        return commit(updated)
    }

    @discardableResult
    public func update(_ ids: [String], status: Status) -> Bool {
        let selected = Set(ids)
        var updated = entries
        for index in updated.indices where selected.contains(updated[index].id) {
            if status == .printed && updated[index].status != .printed {
                updated[index].printedAt = Date()
                updated[index].printCount = (updated[index].printCount ?? 0) + 1
            }
            updated[index].status = status
            if status == .available { updated[index].reservationID = nil }
        }
        return commit(updated)
    }

    /// Returns already printed or unconfirmed stamps to the available stock,
    /// e.g. after a misprint. The print history (date and count) is kept.
    @discardableResult
    public func reuse(_ ids: [String]) -> Bool {
        guard storageError == nil else { return false }
        let selected = Set(ids)
        guard !selected.isEmpty, selected.allSatisfy({ id in
            entries.contains { $0.id == id && ($0.status == .printed || $0.status == .checkPrint) }
        }) else { return false }
        var updated = entries
        for index in updated.indices where selected.contains(updated[index].id) {
            updated[index].status = .available
            updated[index].reservationID = nil
            updated[index].releasedAt = Date()
        }
        return commit(updated)
    }

    @discardableResult
    public func delete(_ ids: [String]) -> Bool {
        guard storageError == nil else { return false }
        let selected = Set(ids)
        guard !selected.isEmpty, selected.allSatisfy({ id in
            entries.contains { $0.id == id && $0.status == .available }
        }) else { return false }
        return commit(entries.filter { !selected.contains($0.id) })
    }

    private func commit(_ updated: [Entry]) -> Bool {
        do {
            try persist(updated)
            entries = updated
            return true
        } catch {
            storageError = "Der Druckstatus konnte nicht gespeichert werden: \(error.localizedDescription)"
            return false
        }
    }

    private func persist(_ entries: [Entry]) throws {
        let data = try JSONEncoder().encode(entries)
        try data.write(to: persistenceURL, options: .atomic)
    }
}
