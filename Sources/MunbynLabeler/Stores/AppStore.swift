import AppKit
import Foundation
import LabelCore

@MainActor
final class AppStore: ObservableObject {
    @Published var showImporter = false
    @Published var showEtsyImporter = false
    @Published var showEtsyImportReview = false
    @Published var showEtsyImportError = false
    @Published var lastMessage: String?
    @Published var selectedJobID: UUID?
    @Published var selectedShipmentKind: ShipmentKind {
        didSet { defaults.set(selectedShipmentKind.rawValue, forKey: Keys.selectedShipmentKind) }
    }
    @Published var speed = 4
    @Published var density = 8
    @Published var selectedFormatID: String {
        didSet { defaults.set(selectedFormatID, forKey: Keys.selectedFormatID) }
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

    let bluetooth = BluetoothPrinterService()
    let jobs = PrintJobStore()
    private let defaults: UserDefaults

    private enum Keys {
        static let selectedFormatID = "selectedLabelFormatID"
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
        selectedShipmentKind = ShipmentKind(
            rawValue: defaults.string(forKey: Keys.selectedShipmentKind) ?? ""
        ) ?? .letter
        selectedFormatID = defaults.string(forKey: Keys.selectedFormatID) ?? LabelFormat.address89x36.id
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
        for url in urls {
            if url.pathExtension.lowercased() == "csv" {
                loadEtsyCSV(url)
                continue
            }
            do {
                let job = try jobs.enqueue(url: url, labelFormat: selectedLabelFormat)
                selectedJobID = job.id
                lastMessage = job.status == .printed
                    ? "Dieses Etikett wurde bereits gedruckt."
                    : "\(url.lastPathComponent) ist druckbereit."
            } catch {
                lastMessage = "Import fehlgeschlagen: \(error.localizedDescription)"
            }
        }
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
        recipientName = order.recipientName
        recipientStreet1 = order.street1
        recipientStreet2 = order.street2
        recipientPostalCode = order.postalCode
        recipientCity = order.city
        recipientCountry = order.country.isEmpty ? "Deutschland" : order.country
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
        } catch {
            lastMessage = "Adressetikett konnte nicht erstellt werden: \(error.localizedDescription)"
        }
    }

    func chooseDHLLabelImport() {
        showEtsyImportReview = false
        selectedShipmentKind = .parcel
        selectedFormatID = LabelFormat.shipping100x150.id
        lastMessage = "Das bei DHL gekaufte Versandlabel jetzt als PDF auswählen."
        showImporter = true
    }
}
