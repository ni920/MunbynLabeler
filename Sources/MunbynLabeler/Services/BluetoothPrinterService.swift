@preconcurrency import CoreBluetooth
import Foundation

struct DiscoveredBluetoothPrinter: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int

    var looksLikeMunbyn: Bool {
        let normalized = name.uppercased()
        return normalized.contains("RW403") || normalized.contains("MUNBYN")
    }
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
        case .discovering: "Druckkanal wird geprüft"
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
    case noWritableCharacteristic

    var errorDescription: String? {
        switch self {
        case .notConnected: "Der Drucker ist nicht verbunden."
        case .transferInProgress: "Ein anderer Druckauftrag wird gerade übertragen."
        case .noWritableCharacteristic: "Der Drucker bietet keinen beschreibbaren Bluetooth-Kanal an."
        }
    }
}

final class BluetoothPrinterService: NSObject, ObservableObject {
    @Published private(set) var connectionState: BluetoothConnectionState = .idle
    @Published private(set) var discoveredDevices: [DiscoveredBluetoothPrinter] = []
    @Published private(set) var diagnostics: [String] = []
    @Published private(set) var transferProgress: Double = 0

    private var centralManager: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var writableCharacteristic: CBCharacteristic?
    private var writeType: CBCharacteristicWriteType = .withResponse
    private var pendingChunks: [Data] = []
    private var totalChunks = 0
    private var writeCompletion: ((Result<Void, Error>) -> Void)?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            connectionState = .unavailable(stateDescription(centralManager.state))
            return
        }
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
        centralManager.stopScan()
        if connectionState == .scanning {
            connectionState = .idle
        }
    }

    func connect(to id: UUID) {
        guard let peripheral = peripherals[id] else { return }
        centralManager.stopScan()
        connectedPeripheral = peripheral
        writableCharacteristic = nil
        peripheral.delegate = self
        connectionState = .connecting(peripheral.name ?? "Unbekanntes Gerät")
        diagnostics.append("Verbinde mit \(peripheral.name ?? id.uuidString)")
        centralManager.connect(peripheral)
    }

    func disconnect() {
        guard let connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(connectedPeripheral)
    }

    func send(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let peripheral = connectedPeripheral,
              peripheral.state == .connected,
              writableCharacteristic != nil else {
            completion(.failure(BluetoothPrinterError.notConnected))
            return
        }
        guard writeCompletion == nil else {
            completion(.failure(BluetoothPrinterError.transferInProgress))
            return
        }

        let maximum = max(20, peripheral.maximumWriteValueLength(for: writeType))
        pendingChunks = data.chunked(maximumLength: maximum)
        totalChunks = pendingChunks.count
        transferProgress = 0
        writeCompletion = completion
        diagnostics.append("Übertragung: \(data.count) Bytes in \(totalChunks) Paketen")
        pumpWrites()
    }

    private func selectWriteCharacteristic(_ characteristic: CBCharacteristic) {
        let canWriteWithResponse = characteristic.properties.contains(.write)
        let canWriteWithoutResponse = characteristic.properties.contains(.writeWithoutResponse)
        guard canWriteWithResponse || canWriteWithoutResponse else { return }

        let uuid = characteristic.uuid.uuidString.uppercased()
        let currentUUID = writableCharacteristic?.uuid.uuidString.uppercased()
        let isPreferred = uuid == "FF02" || uuid.hasSuffix("FF02-0000-1000-8000-00805F9B34FB")
        let currentIsPreferred = currentUUID == "FF02" || currentUUID?.hasSuffix("FF02-0000-1000-8000-00805F9B34FB") == true

        if writableCharacteristic == nil || (isPreferred && !currentIsPreferred) {
            writableCharacteristic = characteristic
            writeType = canWriteWithResponse ? .withResponse : .withoutResponse
        }
    }

    private func finalizeDiscovery(for peripheral: CBPeripheral) {
        guard let characteristic = writableCharacteristic else {
            connectionState = .failed("Kein beschreibbarer GATT-Kanal gefunden. Die Diagnose kann zur Ergänzung eines seriellen Bluetooth-Transports verwendet werden.")
            diagnostics.append("Kein GATT-Schreibkanal gefunden")
            return
        }
        let channel = characteristic.uuid.uuidString
        connectionState = .ready("\(peripheral.name ?? "RW403B") · Kanal \(channel)")
        diagnostics.append("Druckkanal gewählt: \(channel) · \(writeType == .withResponse ? "mit Bestätigung" : "ohne Bestätigung")")
    }

    private func pumpWrites() {
        guard let peripheral = connectedPeripheral,
              let characteristic = writableCharacteristic else {
            finishTransfer(.failure(BluetoothPrinterError.notConnected))
            return
        }

        if pendingChunks.isEmpty {
            finishTransfer(.success(()))
            return
        }

        if writeType == .withResponse {
            let chunk = pendingChunks.removeFirst()
            updateProgress()
            peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
            return
        }

        while peripheral.canSendWriteWithoutResponse, !pendingChunks.isEmpty {
            let chunk = pendingChunks.removeFirst()
            peripheral.writeValue(chunk, for: characteristic, type: .withoutResponse)
            updateProgress()
        }
        if pendingChunks.isEmpty {
            finishTransfer(.success(()))
        }
    }

    private func updateProgress() {
        guard totalChunks > 0 else { return }
        transferProgress = Double(totalChunks - pendingChunks.count) / Double(totalChunks)
    }

    private func finishTransfer(_ result: Result<Void, Error>) {
        let completion = writeCompletion
        writeCompletion = nil
        pendingChunks.removeAll()
        totalChunks = 0
        transferProgress = result.isSuccess ? 1 : 0
        diagnostics.append(result.isSuccess ? "Übertragung abgeschlossen" : "Übertragung abgebrochen")
        completion?(result)
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
        if central.state == .poweredOn {
            if case .unavailable = connectionState {
                connectionState = .idle
            }
        } else {
            connectionState = .unavailable(stateDescription(central.state))
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name
            ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? "Unbenanntes Bluetooth-Gerät"
        peripherals[peripheral.identifier] = peripheral
        let device = DiscoveredBluetoothPrinter(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
        if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[index] = device
        } else {
            discoveredDevices.append(device)
        }
        discoveredDevices.sort {
            if $0.looksLikeMunbyn != $1.looksLikeMunbyn { return $0.looksLikeMunbyn }
            return $0.rssi > $1.rssi
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        diagnostics.append("Verbunden; GATT-Dienste werden gelesen")
        connectionState = .discovering(peripheral.name ?? "RW403B")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionState = .failed(error?.localizedDescription ?? "Das Gerät hat die Verbindung abgelehnt.")
        diagnostics.append("Verbindungsfehler: \(error?.localizedDescription ?? "unbekannt")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        writableCharacteristic = nil
        connectedPeripheral = nil
        if writeCompletion != nil {
            finishTransfer(.failure(error ?? BluetoothPrinterError.notConnected))
        }
        connectionState = error == nil
            ? .idle
            : .failed(error?.localizedDescription ?? "Bluetooth-Verbindung getrennt")
        diagnostics.append("Verbindung getrennt")
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
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            diagnostics.append("Dienst \(service.uuid): \(error.localizedDescription)")
            return
        }
        for characteristic in service.characteristics ?? [] {
            diagnostics.append("Charakteristik \(characteristic.uuid.uuidString): \(characteristic.properties.readableDescription)")
            selectWriteCharacteristic(characteristic)
        }

        let allFinished = peripheral.services?.allSatisfy { $0.characteristics != nil } == true
        if allFinished {
            finalizeDiscovery(for: peripheral)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            finishTransfer(.failure(error))
        } else {
            pumpWrites()
        }
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        pumpWrites()
    }
}

private extension Data {
    func chunked(maximumLength: Int) -> [Data] {
        guard maximumLength > 0 else { return [self] }
        return stride(from: 0, to: count, by: maximumLength).map { offset in
            subdata(in: offset..<Swift.min(offset + maximumLength, count))
        }
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
