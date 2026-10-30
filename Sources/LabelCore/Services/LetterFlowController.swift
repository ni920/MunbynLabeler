import Combine
import Foundation

/// Serializes the two confirmed print jobs and saves a checkpoint before each
/// physical action. A restart or ambiguous failure always requires review.
@MainActor
public final class LetterFlowController: ObservableObject {
    public typealias Printer = (PrintJob, UUID, @escaping (Result<Void, Error>) -> Void) -> Void
    @Published public private(set) var activeFlowID: UUID?
    @Published public private(set) var message: String?
    private let store: LetterFlowStore
    private let postage: PostageStampStore
    private let isReady: () -> Bool
    private let printJob: Printer

    public init(store: LetterFlowStore, postage: PostageStampStore, isReady: @escaping () -> Bool, printJob: @escaping Printer) {
        self.store = store; self.postage = postage; self.isReady = isReady; self.printJob = printJob
        // The printer may have confirmed the stamp just before the app stopped,
        // with only the final flow checkpoint missing.
        for flow in store.flows where flow.stage == .stampCheck {
            if postage.entries.contains(where: { $0.id == flow.stamp.id && $0.status == .printed && $0.reservationID == flow.id }) {
                store.update(flow.id, stage: .completed)
            }
        }
    }

    public func start(_ id: UUID) {
        guard activeFlowID == nil, let flow = store.flow(id), flow.stage == .ready || flow.stage == .addressPrinted else { return }
        guard isReady() else { message = "Bitte den RW403B verbinden und die Materialeinstellung prüfen. Endlosrollen benötigen Firmware ab 1.1.49."; return }
        guard store.storageError == nil, postage.reserve(flow.stamp.id, for: flow.id) else {
            message = store.storageError ?? postage.storageError ?? "Die gewählte Briefmarke ist nicht mehr verfügbar."
            return
        }
        activeFlowID = id; message = nil
        if flow.stage == .ready { printAddress(flow) } else { printStamp(flow) }
    }

    public func resolveAddress(_ id: UUID, alreadyPrinted: Bool) {
        guard activeFlowID == nil, store.flow(id)?.stage == .addressCheck else { return }
        guard store.update(id, stage: alreadyPrinted ? .addressPrinted : .ready) else { return }
        start(id)
    }

    public func resolveStamp(_ id: UUID, alreadyPrinted: Bool) {
        guard activeFlowID == nil, let flow = store.flow(id), flow.stage == .stampCheck else { return }
        guard postage.entries.contains(where: { $0.id == flow.stamp.id && $0.reservationID == id }) else {
            message = "Die Briefmarken-Zuordnung stimmt nicht mit diesem Briefablauf überein."; return
        }
        if alreadyPrinted {
            guard postage.update([flow.stamp.id], status: .printed) else { message = postage.storageError; return }
            store.update(id, stage: .completed)
        } else {
            guard postage.reserve(flow.stamp.id, for: id, afterReview: true), store.update(id, stage: .addressPrinted) else {
                message = postage.storageError ?? store.storageError ?? "Die reservierte Briefmarke konnte nicht freigegeben werden."; return
            }
            start(id)
        }
    }

    private func printAddress(_ flow: LetterShipmentFlow) {
        guard store.update(flow.id, stage: .printingAddress) else { stop(); return }
        printJob(flow.addressJob, flow.id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                guard self.store.update(flow.id, stage: .addressPrinted) else { self.stop(); return }
                self.printStamp(flow)
            case .failure(let error):
                self.store.update(flow.id, stage: .addressCheck, error: error.localizedDescription)
                self.stop()
            }
        }
    }

    private func printStamp(_ flow: LetterShipmentFlow) {
        guard isReady() else {
            store.update(flow.id, stage: .addressPrinted, error: "Adresse gedruckt. Zum Drucken der Briefmarke den RW403B erneut verbinden.")
            stop(); return
        }
        guard store.update(flow.id, stage: .printingStamp) else { stop(); return }
        printJob(flow.stampJob, flow.id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                if self.postage.update([flow.stamp.id], status: .printed) {
                    self.store.update(flow.id, stage: .completed)
                } else {
                    self.store.update(flow.id, stage: .stampCheck, error: self.postage.storageError)
                }
            case .failure(let error):
                let ambiguous = self.postage.entries.contains { $0.id == flow.stamp.id && ($0.status == .checkPrint || $0.status == .printing) }
                self.store.update(flow.id, stage: ambiguous ? .stampCheck : .addressPrinted, error: error.localizedDescription)
            }
            self.stop()
        }
    }

    private func stop() {
        activeFlowID = nil
        if let error = store.storageError ?? postage.storageError { message = error }
    }
}
