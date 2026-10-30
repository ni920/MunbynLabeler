import Foundation
import LabelCore

@MainActor
private final class FlowHarness {
    let postage: PostageStampStore
    let store: LetterFlowStore
    let directory: URL
    let fixture: URL
    var ready = true
    var requested: [UUID] = []
    var pending: [(Result<Void, Error>) -> Void] = []
    lazy var controller = LetterFlowController(store: store, postage: postage,
        isReady: { [unowned self] in ready },
        printJob: { [unowned self] job, owner, completion in
            requested.append(job.id)
            if let ids = job.postageStampIDs {
                precondition(postage.canPrint(ids, reservationID: owner))
                postage.update(ids, status: .printing)
            }
            pending.append { [unowned self] result in
                if case .failure = result, let ids = job.postageStampIDs { postage.update(ids, status: .checkPrint) }
                completion(result)
            }
        })

    init(fixture: URL, directory: URL) throws {
        self.fixture = fixture; self.directory = directory
        postage = PostageStampStore(directory: directory.appendingPathComponent("postage"))
        store = LetterFlowStore(directory: directory.appendingPathComponent("flows"))
        try postage.importBundle(fixture)
    }

    func makeFlow(format: LabelFormat = .product100x50) throws -> LetterShipmentFlow {
        let stamp = postage.entries.first { $0.status == .available }!.stamp
        let id = UUID()
        let address = PrintJob(sourceURL: fixture, sourceFingerprint: "address-\(id)", labelFormat: format, letterFlowID: id)
        let mark = PrintJob(sourceURL: fixture, sourceFingerprint: "stamp-\(id)", labelFormat: format,
                            postageStampIDs: [stamp.id], letterFlowID: id)
        let flow = LetterShipmentFlow(id: id, recipientName: "Testempfänger", orderID: "test-order", stamp: stamp,
                                      addressJob: address, stampJob: mark)
        try store.add(flow)
        return flow
    }

    func finish(_ result: Result<Void, Error>) throws {
        try require(!pending.isEmpty, "Flow scheduled no pending print")
        pending.removeFirst()(result)
    }
}

func runLetterFlowTests(fixture: URL, directory: URL) throws {
    try MainActor.assumeIsolated {
        let success = try FlowHarness(fixture: fixture, directory: directory.appendingPathComponent("success"))
        let flow = try success.makeFlow()
        success.controller.start(flow.id)
        try require(success.requested == [flow.addressJob.id], "Flow must send address first")
        try require(!success.postage.canPrint([flow.stamp.id]), "Reserved stamp leaked into ordinary bundle printing")
        try require(!success.postage.reserve(flow.stamp.id, for: UUID()), "Another flow stole the reserved stamp")
        success.controller.start(flow.id)
        try require(success.requested.count == 1, "Double-click submitted a duplicate address")
        try success.finish(.success(()))
        try require(success.requested == [flow.addressJob.id, flow.stampJob.id], "Stamp must follow confirmed address")
        try success.finish(.success(()))
        try require(success.store.flow(flow.id)?.stage == .completed && success.controller.activeFlowID == nil, "Successful flow did not finish")
        try require(success.postage.entries.first { $0.id == flow.stamp.id }?.status == .printed, "Used stamp did not enter print history")
        try require(success.store.flow(flow.id)?.stamp.trackingNumber == flow.stamp.trackingNumber, "Tracking number lost its recipient/order association")
        success.controller.start(flow.id)
        try require(success.requested.count == 2, "Completed flow was reprinted")

        let continuous = try FlowHarness(fixture: fixture, directory: directory.appendingPathComponent("continuous"))
        let continuousFlow = try continuous.makeFlow(format: .continuousLetter100x55)
        continuous.ready = MunbynFirmwareCapabilities.canPrint(.continuous, firmware: "1.1.48")
        continuous.controller.start(continuousFlow.id)
        try require(continuous.requested.isEmpty && continuous.postage.canPrint([continuousFlow.stamp.id]),
                    "Unsupported continuous firmware must not print or reserve postage")
        continuous.ready = MunbynFirmwareCapabilities.canPrint(.continuous, firmware: "1.1.49")
        continuous.controller.start(continuousFlow.id)
        try continuous.finish(.success(()))
        try require(continuous.requested == [continuousFlow.addressJob.id, continuousFlow.stampJob.id],
                    "Supported continuous flow must proceed from confirmed address to stamp")
        try continuous.finish(.success(()))
        try require(continuous.store.flow(continuousFlow.id)?.stage == .completed && !continuous.postage.canPrint([continuousFlow.stamp.id]),
                    "Continuous stamp must keep the same one-use ledger guarantees")

        let failedAddress = try FlowHarness(fixture: fixture, directory: directory.appendingPathComponent("address-failure"))
        let a = try failedAddress.makeFlow()
        failedAddress.controller.start(a.id)
        try failedAddress.finish(.failure(SelfTestFailure.assertion("simulated address interruption")))
        try require(failedAddress.store.flow(a.id)?.stage == .addressCheck && failedAddress.requested.count == 1, "Address failure must stop before postage")
        failedAddress.controller.resolveAddress(a.id, alreadyPrinted: true)
        try require(failedAddress.requested == [a.addressJob.id, a.stampJob.id], "Confirmed address was printed a second time during recovery")
        try failedAddress.finish(.success(()))

        let disconnected = try FlowHarness(fixture: fixture, directory: directory.appendingPathComponent("disconnect"))
        let d = try disconnected.makeFlow()
        disconnected.ready = false
        disconnected.controller.start(d.id)
        try require(disconnected.requested.isEmpty && disconnected.postage.canPrint([d.stamp.id]), "Preflight failure reserved or printed a stamp")
        disconnected.ready = true
        disconnected.controller.start(d.id)
        disconnected.ready = false
        try disconnected.finish(.success(()))
        try require(disconnected.requested.count == 1 && disconnected.store.flow(d.id)?.stage == .addressPrinted, "Disconnected stamp step did not preserve confirmed address")
        disconnected.ready = true
        disconnected.controller.start(d.id)
        try require(disconnected.requested == [d.addressJob.id, d.stampJob.id], "Resume after disconnect duplicated the address")
        try disconnected.finish(.success(()))

        let failedStamp = try FlowHarness(fixture: fixture, directory: directory.appendingPathComponent("stamp-failure"))
        let s = try failedStamp.makeFlow()
        failedStamp.controller.start(s.id)
        try failedStamp.finish(.success(()))
        try failedStamp.finish(.failure(SelfTestFailure.assertion("simulated stamp interruption")))
        try require(failedStamp.store.flow(s.id)?.stage == .stampCheck, "Ambiguous stamp failure must require review")
        failedStamp.controller.start(s.id)
        try require(failedStamp.requested.count == 2, "Ambiguous stamp was retried without review")
        failedStamp.controller.resolveStamp(s.id, alreadyPrinted: false)
        try require(failedStamp.requested == [s.addressJob.id, s.stampJob.id, s.stampJob.id], "Stamp-only retry printed another address")
        try failedStamp.finish(.success(()))

        let interrupted = try FlowHarness(fixture: fixture, directory: directory.appendingPathComponent("restart"))
        let r = try interrupted.makeFlow()
        interrupted.controller.start(r.id)
        try interrupted.finish(.success(()))
        let restoredPostage = PostageStampStore(directory: interrupted.directory.appendingPathComponent("postage"))
        let restoredFlows = LetterFlowStore(directory: interrupted.directory.appendingPathComponent("flows"))
        var recoveryPrints = 0
        let restored = LetterFlowController(store: restoredFlows, postage: restoredPostage, isReady: { true },
                                           printJob: { _, _, _ in recoveryPrints += 1 })
        try require(restoredFlows.flow(r.id)?.stage == .stampCheck, "Restart during stamp print must require review")
        restored.start(r.id)
        try require(recoveryPrints == 0, "Restart automatically reprinted an uncertain stamp")
        restored.resolveStamp(r.id, alreadyPrinted: true)
        try require(restoredFlows.flow(r.id)?.stage == .completed && recoveryPrints == 0, "Confirming existing stamp submitted a new print")

        let interruptedAddress = try FlowHarness(fixture: fixture, directory: directory.appendingPathComponent("restart-address"))
        let ra = try interruptedAddress.makeFlow()
        interruptedAddress.controller.start(ra.id)
        let restoredAddress = LetterFlowStore(directory: interruptedAddress.directory.appendingPathComponent("flows"))
        try require(restoredAddress.flow(ra.id)?.stage == .addressCheck, "Restart during address print must require review")

        let writeFailure = try FlowHarness(fixture: fixture, directory: directory.appendingPathComponent("save-failure"))
        let w = try writeFailure.makeFlow()
        let blockedDirectory = writeFailure.directory.appendingPathComponent("flows")
        try FileManager.default.removeItem(at: blockedDirectory)
        try Data("not a directory".utf8).write(to: blockedDirectory)
        writeFailure.controller.start(w.id)
        try require(writeFailure.requested.isEmpty && writeFailure.store.storageError != nil, "Flow printed without saving its pre-print checkpoint")
    }
    print("Letter flow tests passed: sequencing, reservations, double-clicks, disconnects, partial failures, restart recovery and checkpoint failures")
}
