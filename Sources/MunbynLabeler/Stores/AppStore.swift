import AppKit
import Foundation
import LabelCore

@MainActor
final class AppStore: ObservableObject {
    @Published var showImporter = false
    @Published var showEtsyImporter = false
    @Published var showEtsyImportReview = false
    @Published var showEtsyImportError = false
    @Published var showBrowserOrderReview = false
    @Published var lastMessage: String?
    @Published var selectedJobID: UUID?
    @Published var previewJob: PrintJob?
    @Published var selectedShipmentKind: ShipmentKind {
        didSet {
            defaults.set(selectedShipmentKind.rawValue, forKey: Keys.selectedShipmentKind)
            selectedFormatID = selectedShipmentKind == .letter
                ? defaults.string(forKey: Keys.lastLetterFormatID) ?? LabelFormat.address89x36.id
                : LabelFormat.shipping100x150.id
        }
    }
    @Published var speed = 4
    @Published var density = 8
    @Published var selectedFormatID: String {
        didSet {
            defaults.set(selectedFormatID, forKey: Keys.selectedFormatID)
            if selectedShipmentKind == .letter {
                defaults.set(selectedFormatID, forKey: Keys.lastLetterFormatID)
            }
        }
    }
    @Published var customWidthMM: Double {
        didSet { defaults.set(customWidthMM, forKey: Keys.customWidthMM) }
    }
    @Published var customHeightMM: Double {
        didSet { defaults.set(customHeightMM, forKey: Keys.customHeightMM) }
    }
    @Published var senderName: String {
        didSet { defaults.set(senderName, forKey: Keys.senderName) }
    }
    @Published var senderStreet: String {
        didSet { defaults.set(senderStreet, forKey: Keys.senderStreet) }
    }
    @Published var senderPostalCode: String {
        didSet { defaults.set(senderPostalCode, forKey: Keys.senderPostalCode) }
    }
    @Published var senderCity: String {
        didSet { defaults.set(senderCity, forKey: Keys.senderCity) }
    }
    @Published var senderCountry: String {
        didSet { defaults.set(senderCountry, forKey: Keys.senderCountry) }
    }
    @Published var recipientName = ""
    @Published var recipientStreet1 = ""
    @Published var recipientStreet2 = ""
    @Published var recipientPostalCode = ""
    @Published var recipientCity = ""
    @Published var recipientCountry = "Deutschland"
    @Published private(set) var pendingEtsyOrders: [EtsyOrder] = []
    @Published private(set) var incomingBrowserOrder: BrowserOrderPayload?
    @Published private(set) var activeBrowserOrder: BrowserOrderPayload?
    @Published private(set) var browserImportSequence = 0

    let bluetooth = BluetoothPrinterService()
    let jobs = PrintJobStore()
    private let defaults: UserDefaults

    private enum Keys {
        static let selectedFormatID = "selectedLabelFormatID"
        static let lastLetterFormatID = "lastLetterLabelFormatID"
        static let selectedShipmentKind = "selectedShipmentKind"
        static let customWidthMM = "customLabelWidthMM"
        static let customHeightMM = "customLabelHeightMM"
        static let senderName = "senderName"
        static let senderStreet = "senderStreet"
        static let senderPostalCode = "senderPostalCode"
        static let senderCity = "senderCity"
        static let senderCountry = "senderCountry"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let initialShipmentKind = ShipmentKind(
            rawValue: defaults.string(forKey: Keys.selectedShipmentKind) ?? ""
        ) ?? .letter
        selectedShipmentKind = initialShipmentKind
        let storedFormatID = defaults.string(forKey: Keys.selectedFormatID)
        if initialShipmentKind == .parcel {
            selectedFormatID = LabelFormat.shipping100x150.id
        } else {
            selectedFormatID = defaults.string(forKey: Keys.lastLetterFormatID)
                ?? storedFormatID
                ?? LabelFormat.address89x36.id
        }
        customWidthMM = defaults.object(forKey: Keys.customWidthMM) as? Double ?? 100
        customHeightMM = defaults.object(forKey: Keys.customHeightMM) as? Double ?? 150
        senderName = defaults.string(forKey: Keys.senderName) ?? ""
        senderStreet = defaults.string(forKey: Keys.senderStreet) ?? ""
        senderPostalCode = defaults.string(forKey: Keys.senderPostalCode) ?? ""
        senderCity = defaults.string(forKey: Keys.senderCity) ?? ""
        senderCountry = defaults.string(forKey: Keys.senderCountry) ?? "Deutschland"
    }

    var selectedLabelFormat: LabelFormat {
        if selectedFormatID == "custom" {
            return .custom(widthMM: customWidthMM, heightMM: customHeightMM)
        }
        return LabelFormat.presets.first(where: { $0.id == selectedFormatID }) ?? .shipping100x150
    }

    var senderAddress: SenderAddress {
        SenderAddress(
            name: senderName,
            street: senderStreet,
            postalCode: senderPostalCode,
            city: senderCity,
            country: senderCountry
        )
    }

    var recipientAddress: RecipientAddress {
        RecipientAddress(
            name: recipientName,
            street1: recipientStreet1,
            street2: recipientStreet2,
            postalCode: recipientPostalCode,
            city: recipientCity,
            country: recipientCountry
        )
    }

    func importFiles(_ urls: [URL]) {
        var lastImportedJob: PrintJob?
        for url in urls {
            if url.pathExtension.lowercased() == "csv" {
                loadEtsyCSV(url)
                continue
            }
            do {
                let job = try jobs.enqueue(url: url, labelFormat: selectedLabelFormat)
                selectedJobID = job.id
                lastImportedJob = job
                lastMessage = job.status == .printed
                    ? "Dieses Etikett wurde bereits gedruckt."
                    : "\(url.lastPathComponent) ist druckbereit."
            } catch {
                lastMessage = "Import fehlgeschlagen: \(error.localizedDescription)"
            }
        }

        if let lastImportedJob {
            // The file importer must finish dismissing before another sheet can open.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.presentPrintPreview(lastImportedJob)
            }
        }
    }

    func handleIncomingURL(_ url: URL) {
        do {
            let order = try BrowserOrderLink.decode(url)
            incomingBrowserOrder = order
            showBrowserOrderReview = true
            browserImportSequence &+= 1
            lastMessage = "Etsy-Bestellung #\(order.orderID) wurde aus dem Browser empfangen."
            NSApp.activate(ignoringOtherApps: true)
        } catch {
            incomingBrowserOrder = nil
            showBrowserOrderReview = false
            lastMessage = "Browser-Import fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    func acceptIncomingBrowserOrder(as shipmentKind: ShipmentKind) {
        guard let order = incomingBrowserOrder else { return }
        applyRecipient(order.recipient)
        activeBrowserOrder = order
        selectedShipmentKind = shipmentKind
        incomingBrowserOrder = nil
        showBrowserOrderReview = false
        browserImportSequence &+= 1
        lastMessage = shipmentKind == .letter
            ? "Etsy-Bestellung #\(order.orderID) wurde ins Briefformular übernommen."
            : "Etsy-Bestellung #\(order.orderID) wurde übernommen. Jetzt das DHL-Paketlabel auswählen."
    }

    func dismissIncomingBrowserOrder() {
        incomingBrowserOrder = nil
        showBrowserOrderReview = false
    }

    func printTestLabel() {
        lastMessage = "Testetikett wird für den RW403B vorbereitet …"
        bluetooth.printRaster(LabelRenderer.testPattern(format: selectedLabelFormat)) { [weak self] result in
            switch result {
            case .success:
                self?.lastMessage = "Testetikett wurde vollständig vom RW403B bestätigt."
            case .failure(let error):
                self?.lastMessage = "Testdruck fehlgeschlagen: \(error.localizedDescription)"
            }
        }
    }

    func printJob(_ job: PrintJob) {
        guard bluetooth.connectionState.isReady else {
            lastMessage = "Bitte zuerst den RW403B verbinden."
            return
        }

        jobs.update(job.id, status: .printing)
        lastMessage = "\(job.sourceURL.lastPathComponent) wird vorbereitet …"

        do {
            let raster = try LabelRenderer.render(url: job.sourceURL, format: job.resolvedLabelFormat)
            bluetooth.printRaster(raster) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    self.jobs.update(job.id, status: .printed)
                    self.lastMessage = "Etikett wurde vollständig vom RW403B bestätigt."
                case .failure(let error):
                    self.jobs.update(job.id, status: .failed, errorMessage: error.localizedDescription)
                    self.lastMessage = "Druck fehlgeschlagen: \(error.localizedDescription)"
                }
            }
        } catch {
            jobs.update(job.id, status: .failed, errorMessage: error.localizedDescription)
            lastMessage = "Aufbereitung fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    func loadEtsyCSV(_ url: URL) {
        let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            pendingEtsyOrders = try EtsyOrderCSVParser.parse(url: url)
            lastMessage = "\(pendingEtsyOrders.count) Etsy-Bestellungen wurden gefunden."
            showEtsyImporter = false

            // A file importer is itself a modal presentation. Opening the review
            // sheet from its completion handler can otherwise be ignored by macOS
            // while the file importer is still being dismissed.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self, !self.pendingEtsyOrders.isEmpty else { return }
                self.showEtsyImportReview = true
            }
        } catch {
            pendingEtsyOrders = []
            let message = error.localizedDescription
            lastMessage = "Etsy-Import fehlgeschlagen: \(message)"
            showEtsyImporter = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showEtsyImportError = true
            }
        }
    }

    func applyEtsyOrder(_ order: EtsyOrder) {
        applyRecipient(order.recipientAddress)
        activeBrowserOrder = nil
        selectedShipmentKind = .letter
        showEtsyImportReview = false
        pendingEtsyOrders = []
        lastMessage = "Die Adresse von \(order.recipientName) wurde ins Formular übernommen."
    }

    func createManualAddressLabel() {
        guard recipientAddress.isComplete else {
            lastMessage = "Bitte die vollständige Empfängeradresse eingeben."
            return
        }
        guard senderAddress.isComplete else {
            lastMessage = "Bitte den vollständigen Absender eingeben."
            return
        }

        do {
            let url = try EtsyAddressLabelWriter.write(
                recipient: recipientAddress,
                sender: senderAddress,
                format: selectedLabelFormat
            )
            let job = try jobs.enqueue(
                url: url,
                labelFormat: selectedLabelFormat,
                displayName: "Brief · \(recipientAddress.name)",
                sourceFingerprint: "manual-address:\(UUID().uuidString)"
            )
            selectedJobID = job.id
            lastMessage = "Das Adressetikett für \(recipientAddress.name) ist druckbereit."
            presentPrintPreview(job)
        } catch {
            lastMessage = "Adressetikett konnte nicht erstellt werden: \(error.localizedDescription)"
        }
    }

    func chooseDHLLabelImport() {
        showEtsyImportReview = false
        selectedShipmentKind = .parcel
        lastMessage = "Das bei DHL gekaufte Versandlabel jetzt als PDF auswählen."
        showImporter = true
    }

    func presentPrintPreview(_ job: PrintJob) {
        guard FileManager.default.fileExists(atPath: job.sourceURL.path) else {
            lastMessage = "Die Quelldatei für diese Vorschau wurde nicht gefunden."
            return
        }
        selectedJobID = job.id
        previewJob = job
    }

    func closePrintPreview() {
        previewJob = nil
    }

    func printFromPreview(_ job: PrintJob) {
        previewJob = nil
        printJob(job)
    }

    private func applyRecipient(_ recipient: RecipientAddress) {
        recipientName = recipient.name
        recipientStreet1 = recipient.street1
        recipientStreet2 = recipient.street2
        recipientPostalCode = recipient.postalCode
        recipientCity = recipient.city
        recipientCountry = recipient.country.isEmpty ? "Deutschland" : recipient.country
    }
}
