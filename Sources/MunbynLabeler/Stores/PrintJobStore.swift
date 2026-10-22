import Foundation
import LabelCore

@MainActor
final class PrintJobStore: ObservableObject {
    @Published private(set) var jobs: [PrintJob] = []

    private let persistenceURL: URL

    init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("MunbynLabeler", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        persistenceURL = directory.appendingPathComponent("print-jobs.json")
        load()
    }

    @discardableResult
    func enqueue(url: URL) throws -> PrintJob {
        let fingerprint = try FileFingerprint.sha256LikeFingerprint(for: url)
        if let existing = jobs.first(where: {
            $0.sourceFingerprint == fingerprint && $0.status != .failed
        }) {
            return existing
        }

        let job = PrintJob(sourceURL: url, sourceFingerprint: fingerprint)
        jobs.insert(job, at: 0)
        persist()
        return job
    }

    func update(_ id: UUID, status: PrintJob.Status, errorMessage: String? = nil) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].status = status
        jobs[index].errorMessage = errorMessage
        persist()
    }

    func retry(_ id: UUID) {
        update(id, status: .ready)
    }

    func clearCompleted() {
        jobs.removeAll { $0.status == .printed }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: persistenceURL),
              let decoded = try? JSONDecoder().decode([PrintJob].self, from: data) else {
            return
        }
        jobs = decoded.map { job in
            var restored = job
            if restored.status == .printing {
                restored.status = .ready
            }
            return restored
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(jobs) else { return }
        try? data.write(to: persistenceURL, options: .atomic)
    }
}
