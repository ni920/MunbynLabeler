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
    @Published private(set) var pendingEtsyOrders: [EtsyOrder] = []

    let bluetooth = BluetoothPrinterService()
    let jobs = PrintJobStore()
    private let defaults: UserDefaults

    private enum Keys {
        static let selectedFormatID = "selectedLabelFormatID"
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
        selectedFormatID = defaults.string(forKey: Keys.selectedFormatID) ?? LabelFormat.shipping100x150.id
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

    func createEtsyAddressLabels(orderIDs: Set<String>) {
        guard senderAddress.isComplete else {
            lastMessage = "Bitte zuerst den vollständigen Absender eingeben."
            return
        }

        let selected = pendingEtsyOrders.filter { orderIDs.contains($0.id) }
        guard !selected.isEmpty else {
            lastMessage = "Bitte mindestens eine Etsy-Bestellung auswählen."
            return
        }

        var created = 0
        for order in selected {
            do {
                let url = try EtsyAddressLabelWriter.write(
                    order: order,
                    sender: senderAddress,
                    format: selectedLabelFormat
                )
                let addressFingerprint = [
                    "etsy", order.id, order.recipientLines.joined(separator: "|"), senderAddress.singleLine
                ].joined(separator: ":")
                let job = try jobs.enqueue(
                    url: url,
                    labelFormat: selectedLabelFormat,
                    displayName: "Etsy #\(order.id) · \(order.recipientName)",
                    sourceFingerprint: addressFingerprint
                )
                selectedJobID = job.id
                created += 1
            } catch {
                lastMessage = "Etsy-Etikett konnte nicht erstellt werden: \(error.localizedDescription)"
                return
            }
        }

        showEtsyImportReview = false
        pendingEtsyOrders = []
        lastMessage = "\(created) Etsy-Adressetikett\(created == 1 ? "" : "en") ist druckbereit."
    }

    func chooseDHLLabelImport() {
        showEtsyImportReview = false
        lastMessage = "Das bei DHL gekaufte Versandlabel jetzt als PDF auswählen."
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.showImporter = true
        }
    }
}
