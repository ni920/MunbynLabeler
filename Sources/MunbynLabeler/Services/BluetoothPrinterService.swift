@preconcurrency import CoreBluetooth
import Foundation
import LabelCore

struct DiscoveredBluetoothPrinter: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int
}

enum BluetoothConnectionState: Equatable {
    case unavailable(String)
    case idle
    case scanning
    case connecting(String)
    case discovering(String)
    case ready(String)
    case failed(String)

    var title: String {
        switch self {
        case .unavailable: "Bluetooth nicht verfügbar"
        case .idle: "Nicht verbunden"
        case .scanning: "Suche läuft"
        case .connecting: "Verbindung wird aufgebaut"
        case .discovering: "RW403B-Protokoll wird geprüft"
        case .ready: "Drucker verbunden"
        case .failed: "Verbindung fehlgeschlagen"
        }
    }

    var detail: String? {
        switch self {
        case .unavailable(let detail), .connecting(let detail), .discovering(let detail),
             .ready(let detail), .failed(let detail): detail
        case .idle: "RW403B einschalten und die Suche starten."
        case .scanning: "Bluetooth-Geräte in der Nähe werden gesucht."
        }
    }

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

enum BluetoothPrinterError: LocalizedError {
    case notConnected
    case transferInProgress
    case incompatiblePrinter
    case emptyPrintData
    case frameTooLarge(Int, Int)
    case responseTimeout(Int)
    case printCompletionTimeout
    case printerNotReady(String)
    case printerRejected(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: "Der RW403B ist nicht verbunden."
        case .transferInProgress: "Ein anderer Druckauftrag wird gerade übertragen."
        case .incompatiblePrinter: "Die benötigten RW403B-Kanäle ABF1, ABF3 und ABF4 wurden nicht gefunden."
        case .emptyPrintData: "Das Etikett enthält keine Druckdaten."
        case .frameTooLarge(let actual, let maximum):
            "Ein Bluetooth-Paket ist mit \(actual) Bytes größer als die erlaubten \(maximum) Bytes."
        case .responseTimeout(let section):
            "Der Drucker hat Datenabschnitt \(section) nicht bestätigt."
        case .printCompletionTimeout:
            "Der RW403B hat den abgeschlossenen Druck nicht bestätigt."
        case .printerNotReady(let detail): "Der RW403B ist nicht druckbereit: \(detail)"
        case .printerRejected(let detail): "Der Drucker hat den Auftrag abgelehnt: \(detail)"
        }
    }
}

final class BluetoothPrinterService: NSObject, ObservableObject {
    @Published private(set) var connectionState: BluetoothConnectionState = .idle
    @Published private(set) var discoveredDevices: [DiscoveredBluetoothPrinter] = []
    @Published private(set) var diagnostics: [String] = []
    @Published private(set) var transferProgress: Double = 0
    @Published private(set) var printerStatusMessage: String?

    private enum PrintPhase {
        case sending
        case waitingForSectionAck
        case waitingForPrintCompletion
    }

    private struct PrintTransfer {
        let sections: [MunbynPrintSection]
        let totalFrames: Int
        let completion: (Result<Void, Error>) -> Void
        var sectionIndex = 0
        var frameIndex = 0
        var sentFrames = 0
        var phase: PrintPhase = .sending
    }

    private enum ActiveTransfer {
        case preparing((Result<Void, Error>) -> Void)
        case selfTest((Result<Void, Error>) -> Void)
        case print(PrintTransfer)
    }

    private var centralManager: CBCentralManager?
    private var scanRequested = false
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var dataCharacteristic: CBCharacteristic?
    private var controlCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var notificationRequested = false
    private var latestPrintStatus = 0
    private var activeTransfer: ActiveTransfer?
    private var frameDecoder = MunbynFrameDecoder()
    private var connectionHandshakePending = false
    private var connectionHandshakeTimeout: DispatchWorkItem?
    private var sectionAckTimeout: DispatchWorkItem?
    private var printCompletionTimeout: DispatchWorkItem?
    private var pacedWrite: DispatchWorkItem?
    private var reconnectWorkItem: DispatchWorkItem?
    private var reconnectAttempt = 0
    private var userRequestedDisconnect = false

    private let rememberedPrinterIDKey = "rememberedRW403BPeripheralID"
    private let rememberedPrinterNameKey = "rememberedRW403BPeripheralName"

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func startScanning() {
        scanRequested = true
        guard let centralManager else {
            connectionState = .unavailable("Bluetooth konnte nicht initialisiert werden.")
            return
        }
        guard centralManager.state == .poweredOn else {
            connectionState = .unavailable(stateDescription(centralManager.state))
            return
        }
        scanRequested = false
        discoveredDevices.removeAll()
        peripherals.removeAll()
        diagnostics = ["Bluetooth-Suche gestartet"]
        connectionState = .scanning
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScanning() {
        scanRequested = false
        centralManager?.stopScan()
        if connectionState == .scanning { connectionState = .idle }
    }

    func connect(to id: UUID) {
        guard let centralManager, let peripheral = peripherals[id] else { return }
        userRequestedDisconnect = false
        reconnectAttempt = 0
        beginConnection(to: peripheral, using: centralManager, isReconnect: false)
    }

    func disconnect() {
        guard let centralManager, let connectedPeripheral else { return }
        userRequestedDisconnect = true
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        forgetRememberedPrinter()
        centralManager.cancelPeripheralConnection(connectedPeripheral)
    }

    private func beginConnection(
        to peripheral: CBPeripheral,
        using central: CBCentralManager,
        isReconnect: Bool
    ) {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        central.stopScan()
        peripherals[peripheral.identifier] = peripheral
        connectedPeripheral = peripheral
        clearCharacteristics()
        peripheral.delegate = self
        let name = peripheral.name ?? rememberedPrinterName ?? "RW403B"
        connectionState = .connecting(
            isReconnect ? "\(name) · Verbindung wird wiederhergestellt" : name
        )
        diagnostics.append(isReconnect ? "Verbinde RW403B automatisch erneut" : "Verbinde mit \(name)")
        central.connect(
            peripheral,
            options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true]
        )
    }

    private func rememberPrinter(_ peripheral: CBPeripheral) {
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: rememberedPrinterIDKey)
        UserDefaults.standard.set(peripheral.name ?? "RW403B", forKey: rememberedPrinterNameKey)
    }

    private func forgetRememberedPrinter() {
        UserDefaults.standard.removeObject(forKey: rememberedPrinterIDKey)
        UserDefaults.standard.removeObject(forKey: rememberedPrinterNameKey)
    }

    private var rememberedPrinterID: UUID? {
        UserDefaults.standard.string(forKey: rememberedPrinterIDKey).flatMap(UUID.init(uuidString:))
    }

    private var rememberedPrinterName: String? {
        UserDefaults.standard.string(forKey: rememberedPrinterNameKey)
    }

    private func restoreRememberedPrinter(using central: CBCentralManager) -> Bool {
        guard !userRequestedDisconnect, let id = rememberedPrinterID else { return false }
        guard let peripheral = central.retrievePeripherals(withIdentifiers: [id]).first else {
            diagnostics.append("Gespeicherter RW403B ist derzeit nicht erreichbar")
            return false
        }
        beginConnection(to: peripheral, using: central, isReconnect: true)
        return true
    }

    private func scheduleReconnect(to peripheral: CBPeripheral, using central: CBCentralManager) {
        guard !userRequestedDisconnect, rememberedPrinterID == peripheral.identifier else {
            connectedPeripheral = nil
            connectionState = .idle
            return
        }

        reconnectWorkItem?.cancel()
        reconnectAttempt += 1
        let delay = min(8, 1 << min(reconnectAttempt - 1, 3))
        let name = peripheral.name ?? rememberedPrinterName ?? "RW403B"
        connectionState = .connecting("\(name) · neuer Versuch in \(delay) s")
        diagnostics.append("RW403B getrennt; automatische Wiederverbindung in \(delay) s")

        let work = DispatchWorkItem { [weak self, weak peripheral] in
            guard let self, let peripheral, central.state == .poweredOn else { return }
            self.beginConnection(to: peripheral, using: central, isReconnect: true)
        }
        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay), execute: work)
    }

    func printSelfTest(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let peripheral = readyPeripheral(), let controlCharacteristic else {
            completion(.failure(BluetoothPrinterError.notConnected))
            return
        }
        guard activeTransfer == nil else {
            completion(.failure(BluetoothPrinterError.transferInProgress))
            return
        }

        activeTransfer = .selfTest(completion)
        transferProgress = 0
        let frame = MunbynRW403BProtocol.selfTestFrame()
        diagnostics.append("Drucker-Selbsttest: \(frame.count) Bytes über ABF1")
        peripheral.writeValue(frame, for: controlCharacteristic, type: .withResponse)
    }

    func printRaster(_ raster: LabelRaster, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let peripheral = readyPeripheral() else {
            completion(.failure(BluetoothPrinterError.notConnected))
            return
        }
        guard activeTransfer == nil else {
            completion(.failure(BluetoothPrinterError.transferInProgress))
            return
        }
        guard latestPrintStatus == 0 else {
            completion(.failure(BluetoothPrinterError.printerNotReady(statusDescription(latestPrintStatus))))
            return
        }

        activeTransfer = .preparing(completion)
        transferProgress = 0
        diagnostics.append("RW403B-Druckdaten werden komprimiert")
        let maximumWriteLength = peripheral.maximumWriteValueLength(for: .withoutResponse)
        let imageChunkLength = max(20, min(400, maximumWriteLength - 64))

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let sections = MunbynRW403BProtocol.printSections(
                raster: raster,
                maximumImageChunkLength: imageChunkLength
            )
            DispatchQueue.main.async {
                self?.beginPreparedPrint(sections, completion: completion)
            }
        }
    }

    private func beginPreparedPrint(
        _ sections: [MunbynPrintSection],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard case .preparing = activeTransfer else { return }
        guard readyPeripheral() != nil else {
            finishTransfer(.failure(BluetoothPrinterError.notConnected))
            return
        }
        guard !sections.isEmpty else {
            finishTransfer(.failure(BluetoothPrinterError.emptyPrintData))
            return
        }

        let totalFrames = sections.reduce(0) { $0 + $1.frames.count }
        activeTransfer = .print(PrintTransfer(
            sections: sections,
            totalFrames: totalFrames,
            completion: completion
        ))
        diagnostics.append("Druckauftrag: \(sections.count) Abschnitte, \(totalFrames) Bluetooth-Pakete")
        sendNextPrintFrame()
    }

    private func sendNextPrintFrame() {
        guard let peripheral = readyPeripheral(), let dataCharacteristic else {
            finishTransfer(.failure(BluetoothPrinterError.notConnected))
            return
        }
        guard case .print(var transfer) = activeTransfer,
              transfer.phase == .sending else { return }

        let section = transfer.sections[transfer.sectionIndex]
        guard transfer.frameIndex < section.frames.count else {
            transfer.phase = .waitingForSectionAck
            activeTransfer = .print(transfer)
            waitForSectionAcknowledgement(section.index)
            return
        }

        guard peripheral.canSendWriteWithoutResponse else {
            activeTransfer = .print(transfer)
            return
        }

        let frame = section.frames[transfer.frameIndex]
        let maximum = peripheral.maximumWriteValueLength(for: .withoutResponse)
        guard frame.count <= maximum else {
            finishTransfer(.failure(BluetoothPrinterError.frameTooLarge(frame.count, maximum)))
            return
        }

        peripheral.writeValue(frame, for: dataCharacteristic, type: .withoutResponse)
        transfer.frameIndex += 1
        transfer.sentFrames += 1
        transferProgress = Double(transfer.sentFrames) / Double(max(1, transfer.totalFrames + 1))

        if transfer.frameIndex == section.frames.count {
            transfer.phase = .waitingForSectionAck
            activeTransfer = .print(transfer)
            diagnostics.append("Abschnitt \(section.index)/\(transfer.sections.count) gesendet; warte auf ABF3-Bestätigung")
            waitForSectionAcknowledgement(section.index)
        } else {
            activeTransfer = .print(transfer)
            let work = DispatchWorkItem { [weak self] in self?.sendNextPrintFrame() }
            pacedWrite = work
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(3), execute: work)
        }
    }

    private func waitForSectionAcknowledgement(_ section: Int) {
        sectionAckTimeout?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  case .print(let transfer) = self.activeTransfer,
                  transfer.phase == .waitingForSectionAck else { return }
            self.finishTransfer(.failure(BluetoothPrinterError.responseTimeout(section)))
        }
        sectionAckTimeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
    }

    private func acceptCurrentSection() {
        guard case .print(var transfer) = activeTransfer,
              transfer.phase == .waitingForSectionAck else { return }
        sectionAckTimeout?.cancel()
        sectionAckTimeout = nil
        diagnostics.append("Abschnitt \(transfer.sectionIndex + 1) bestätigt")
        transfer.sectionIndex += 1
        transfer.frameIndex = 0

        if transfer.sectionIndex == transfer.sections.count {
            guard let peripheral = readyPeripheral(), let controlCharacteristic else {
                finishTransfer(.failure(BluetoothPrinterError.notConnected))
                return
            }
            transfer.phase = .waitingForPrintCompletion
            activeTransfer = .print(transfer)
            transferProgress = Double(transfer.totalFrames) / Double(max(1, transfer.totalFrames + 1))
            let frame = MunbynRW403BProtocol.printEndFrame()
            diagnostics.append("Alle Abschnitte bestätigt; Druckende über ABF1, warte auf Druckstatus")
            peripheral.writeValue(frame, for: controlCharacteristic, type: .withResponse)
            waitForPrintCompletion()
        } else {
            transfer.phase = .sending
            activeTransfer = .print(transfer)
            sendNextPrintFrame()
        }
    }

    private func handleResponse(_ response: MunbynPrinterResponse) {
        diagnostics.append(response.diagnosticDescription)
        switch response {
        case .deviceInfo(let printStatus, _, _):
            latestPrintStatus = printStatus
            printerStatusMessage = printStatus == 0 ? nil : statusDescription(printStatus)
            if connectionHandshakePending, let peripheral = connectedPeripheral {
                finalizeConnection(for: peripheral)
            } else {
                refreshReadyConnectionStatus()
            }
        case .printStatus(let rawStatus):
            if let printStatus = Int(rawStatus) {
                latestPrintStatus = printStatus
                printerStatusMessage = printStatus == 0 ? nil : statusDescription(printStatus)
                refreshReadyConnectionStatus()
                if case .print(let transfer) = activeTransfer,
                   transfer.phase == .waitingForPrintCompletion {
                    if printStatus == 0 {
                        diagnostics.append("RW403B meldet: Etikett gedruckt")
                        finishTransfer(.success(()))
                    } else {
                        finishTransfer(.failure(
                            BluetoothPrinterError.printerNotReady(statusDescription(printStatus))
                        ))
                    }
                }
            }
        case .sectionAccepted:
            acceptCurrentSection()
        case .error(let detail):
            finishTransfer(.failure(BluetoothPrinterError.printerRejected(detail)))
        default:
            break
        }
    }

    private func finishTransfer(_ result: Result<Void, Error>) {
        sectionAckTimeout?.cancel()
        printCompletionTimeout?.cancel()
        pacedWrite?.cancel()
        sectionAckTimeout = nil
        printCompletionTimeout = nil
        pacedWrite = nil

        let completion: ((Result<Void, Error>) -> Void)?
        switch activeTransfer {
        case .preparing(let callback), .selfTest(let callback): completion = callback
        case .print(let transfer): completion = transfer.completion
        case nil: completion = nil
        }
        activeTransfer = nil
        transferProgress = result.isSuccess ? 1 : 0
        diagnostics.append(result.isSuccess ? "Druck vom RW403B abgeschlossen" : "Druckübertragung abgebrochen")
        completion?(result)
    }

    private func waitForPrintCompletion() {
        printCompletionTimeout?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  case .print(let transfer) = self.activeTransfer,
                  transfer.phase == .waitingForPrintCompletion else { return }
            self.finishTransfer(.failure(BluetoothPrinterError.printCompletionTimeout))
        }
        printCompletionTimeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: work)
    }

    private func readyPeripheral() -> CBPeripheral? {
        guard connectionState.isReady,
              let peripheral = connectedPeripheral,
              peripheral.state == .connected,
              dataCharacteristic != nil,
              controlCharacteristic != nil,
              notifyCharacteristic?.isNotifying == true else { return nil }
        return peripheral
    }

    private func selectProtocolCharacteristic(_ characteristic: CBCharacteristic, service: CBService) {
        guard service.uuid.uuidString.uppercased() == MunbynRW403BProtocol.serviceUUID else { return }
        switch characteristic.uuid.uuidString.uppercased() {
        case MunbynRW403BProtocol.dataCharacteristicUUID:
            if characteristic.properties.contains(.writeWithoutResponse) { dataCharacteristic = characteristic }
        case MunbynRW403BProtocol.controlCharacteristicUUID:
            if characteristic.properties.contains(.write) { controlCharacteristic = characteristic }
        case MunbynRW403BProtocol.notifyCharacteristicUUID:
            if characteristic.properties.contains(.notify) { notifyCharacteristic = characteristic }
        default:
            break
        }
    }

    private func finishCharacteristicDiscovery(for peripheral: CBPeripheral) {
        guard dataCharacteristic != nil,
              controlCharacteristic != nil,
              let notifyCharacteristic else {
            connectionState = .failed(BluetoothPrinterError.incompatiblePrinter.localizedDescription)
            diagnostics.append("RW403B-Protokoll unvollständig: ABF1/ABF3/ABF4 erforderlich")
            return
        }
        if notifyCharacteristic.isNotifying {
            requestDeviceInfo(from: peripheral)
        } else if !notificationRequested {
            notificationRequested = true
            diagnostics.append("Aktiviere Druckerantworten über ABF3")
            peripheral.setNotifyValue(true, for: notifyCharacteristic)
        }
    }

    private func finalizeConnection(for peripheral: CBPeripheral) {
        guard !userRequestedDisconnect else { return }
        connectionHandshakeTimeout?.cancel()
        connectionHandshakeTimeout = nil
        connectionHandshakePending = false
        let dataMaximum = peripheral.maximumWriteValueLength(for: .withoutResponse)
        let controlMaximum = peripheral.maximumWriteValueLength(for: .withResponse)
        let status = latestPrintStatus == 0 ? "druckbereit" : statusDescription(latestPrintStatus)
        connectionState = .ready("\(peripheral.name ?? "RW403B") · \(status)")
        reconnectAttempt = 0
        userRequestedDisconnect = false
        rememberPrinter(peripheral)
        diagnostics.append("RW403B bereit: ABF4 Daten (max. \(dataMaximum)), ABF1 Steuerung (max. \(controlMaximum)), ABF3 Antworten")
    }

    private func refreshReadyConnectionStatus() {
        guard connectionState.isReady, let peripheral = connectedPeripheral else { return }
        let status = latestPrintStatus == 0 ? "druckbereit" : statusDescription(latestPrintStatus)
        connectionState = .ready("\(peripheral.name ?? "RW403B") · \(status)")
    }

    private func requestDeviceInfo(from peripheral: CBPeripheral) {
        guard !connectionHandshakePending,
              !connectionState.isReady,
              let controlCharacteristic else { return }
        connectionHandshakePending = true
        diagnostics.append("RW403B-Geräteinfo wird über ABF1 abgefragt")
        peripheral.writeValue(MunbynRW403BProtocol.deviceInfoFrame(), for: controlCharacteristic, type: .withResponse)

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.connectionHandshakePending else { return }
            self.connectionHandshakePending = false
            self.connectionState = .failed("Der RW403B hat den Geräteinfo-Handshake nicht beantwortet.")
            self.diagnostics.append("Geräteinfo-Handshake abgebrochen")
        }
        connectionHandshakeTimeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    private func clearCharacteristics() {
        dataCharacteristic = nil
        controlCharacteristic = nil
        notifyCharacteristic = nil
        notificationRequested = false
        latestPrintStatus = 0
        printerStatusMessage = nil
        connectionHandshakeTimeout?.cancel()
        connectionHandshakeTimeout = nil
        connectionHandshakePending = false
        frameDecoder = MunbynFrameDecoder()
    }

    private func statusDescription(_ status: Int) -> String {
        var issues: [String] = []
        if status & (1 << 0) != 0 { issues.append("Drucker ist beschäftigt") }
        if status & (1 << 1) != 0 { issues.append("Papier wird nicht erkannt") }
        if status & (1 << 2) != 0 { issues.append("Druckspeicher ist voll") }
        if status & (1 << 3) != 0 { issues.append("Abdeckung ist geöffnet") }
        if status & (1 << 4) != 0 { issues.append("Papierstau") }
        if status & (1 << 5) != 0 { issues.append("Druckkopf ist zu heiß") }
        if status & (1 << 6) != 0 { issues.append("Akkustand ist niedrig") }
        if status & (1 << 7) != 0 { issues.append("Motor ist zu heiß") }
        if status & (1 << 8) != 0 { issues.append("Papier wird kalibriert") }
        return issues.isEmpty ? "unbekannter Druckstatus \(status)" : issues.joined(separator: ", ")
    }

    private func stateDescription(_ state: CBManagerState) -> String {
        switch state {
        case .unknown: "Bluetooth-Status ist noch unbekannt."
        case .resetting: "Bluetooth wird gerade zurückgesetzt."
        case .unsupported: "Dieser Mac unterstützt den benötigten Bluetooth-Modus nicht."
        case .unauthorized: "Bluetooth-Zugriff wurde nicht erlaubt."
        case .poweredOff: "Bluetooth ist ausgeschaltet."
        case .poweredOn: "Bluetooth ist bereit."
        @unknown default: "Unbekannter Bluetooth-Status."
        }
    }
}

extension BluetoothPrinterService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        diagnostics.append("Bluetooth-Status: \(stateDescription(central.state))")
        if central.state == .poweredOn {
            if scanRequested {
                startScanning()
            } else if restoreRememberedPrinter(using: central) {
                diagnostics.append("Gespeicherter RW403B wird automatisch verbunden")
            } else if case .unavailable = connectionState {
                connectionState = .idle
            }
        } else {
            scanRequested = false
            reconnectWorkItem?.cancel()
            reconnectWorkItem = nil
            connectionState = .unavailable(stateDescription(central.state))
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? peripheral.name
            ?? "Unbenanntes Bluetooth-Gerät"
        let advertisedServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let advertisesRW403BProtocol = advertisedServices.contains {
            $0.uuidString.uppercased() == MunbynRW403BProtocol.serviceUUID
        }
        guard SupportedBluetoothPrinter.matches(name: name) || advertisesRW403BProtocol else { return }
        peripherals[peripheral.identifier] = peripheral
        let device = DiscoveredBluetoothPrinter(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index] = device
        } else {
            discoveredDevices.append(device)
        }
        discoveredDevices.sort { $0.rssi > $1.rssi }

        if !userRequestedDisconnect,
           rememberedPrinterID == peripheral.identifier,
           connectedPeripheral?.state != .connected {
            beginConnection(to: peripheral, using: central, isReconnect: true)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        diagnostics.append("Verbunden; GATT-Dienste werden gelesen")
        connectionState = .discovering(peripheral.name ?? "RW403B")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        diagnostics.append("Verbindungsfehler: \(error?.localizedDescription ?? "unbekannt")")
        if !userRequestedDisconnect, rememberedPrinterID == peripheral.identifier {
            scheduleReconnect(to: peripheral, using: central)
        } else {
            connectionState = .failed(error?.localizedDescription ?? "Das Gerät hat die Verbindung abgelehnt.")
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if activeTransfer != nil {
            finishTransfer(.failure(error ?? BluetoothPrinterError.notConnected))
        }
        clearCharacteristics()
        diagnostics.append("Verbindung getrennt\(error.map { ": \($0.localizedDescription)" } ?? "")")
        if userRequestedDisconnect {
            connectedPeripheral = nil
            connectionState = .idle
        } else {
            scheduleReconnect(to: peripheral, using: central)
        }
    }
}

extension BluetoothPrinterService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            connectionState = .failed(error.localizedDescription)
            return
        }
        guard let services = peripheral.services, !services.isEmpty else {
            connectionState = .failed("Das Gerät meldet keine Bluetooth-Dienste.")
            return
        }
        diagnostics.append("Dienste: \(services.map { $0.uuid.uuidString }.joined(separator: ", "))")
        for service in services { peripheral.discoverCharacteristics(nil, for: service) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            diagnostics.append("Dienst \(service.uuid): \(error.localizedDescription)")
            return
        }
        for characteristic in service.characteristics ?? [] {
            diagnostics.append("Dienst \(service.uuid) · Charakteristik \(characteristic.uuid): \(characteristic.properties.readableDescription)")
            selectProtocolCharacteristic(characteristic, service: service)
        }

        let allFinished = peripheral.services?.allSatisfy { $0.characteristics != nil } == true
        if allFinished { finishCharacteristicDiscovery(for: peripheral) }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid.uuidString.uppercased() == MunbynRW403BProtocol.notifyCharacteristicUUID else { return }
        if let error {
            connectionState = .failed("ABF3-Benachrichtigungen konnten nicht aktiviert werden: \(error.localizedDescription)")
            diagnostics.append("ABF3-Fehler: \(error.localizedDescription)")
        } else if characteristic.isNotifying {
            diagnostics.append("ABF3-Benachrichtigungen aktiv")
            requestDeviceInfo(from: peripheral)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            diagnostics.append("ABF3-Lesefehler: \(error.localizedDescription)")
            return
        }
        guard characteristic.uuid.uuidString.uppercased() == MunbynRW403BProtocol.notifyCharacteristicUUID,
              let value = characteristic.value else { return }
        diagnostics.append("ABF3 empfangen: \(value.count) Bytes")
        for payload in frameDecoder.append(value) {
            if let response = MunbynRW403BProtocol.parseResponse(payload) {
                handleResponse(response)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            finishTransfer(.failure(error))
            return
        }
        guard characteristic.uuid.uuidString.uppercased() == MunbynRW403BProtocol.controlCharacteristicUUID else { return }
        switch activeTransfer {
        case .selfTest:
            finishTransfer(.success(()))
        case .print(let transfer) where transfer.phase == .waitingForPrintCompletion:
            diagnostics.append("Druckende vom Bluetooth-Kanal angenommen")
        default:
            break
        }
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        sendNextPrintFrame()
    }
}

private extension CBCharacteristicProperties {
    var readableDescription: String {
        var values: [String] = []
        if contains(.read) { values.append("read") }
        if contains(.write) { values.append("write") }
        if contains(.writeWithoutResponse) { values.append("writeWithoutResponse") }
        if contains(.notify) { values.append("notify") }
        if contains(.indicate) { values.append("indicate") }
        return values.isEmpty ? "keine relevanten Eigenschaften" : values.joined(separator: ", ")
    }
}

private extension Result where Success == Void, Failure == Error {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
