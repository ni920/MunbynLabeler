import AppKit
import Foundation
import LabelCore

@MainActor
final class AppStore: ObservableObject {
    @Published var showImporter = false
    @Published var lastMessage: String?
    @Published var selectedJobID: UUID?
    @Published var speed = 4
    @Published var density = 8

    let bluetooth = BluetoothPrinterService()
    let jobs = PrintJobStore()

    func importFiles(_ urls: [URL]) {
        for url in urls {
            do {
                let job = try jobs.enqueue(url: url)
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
        lastMessage = "Testetikett wird übertragen …"
        bluetooth.send(TSPLCommandBuilder.testLabel()) { [weak self] result in
            switch result {
            case .success:
                self?.lastMessage = "Testetikett wurde an den Drucker übertragen."
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
            let raster = try LabelRenderer.render(url: job.sourceURL)
            let command = TSPLCommandBuilder.bitmapJob(
                raster: raster,
                speed: speed,
                density: density
            )
            bluetooth.send(command) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    self.jobs.update(job.id, status: .printed)
                    self.lastMessage = "Etikett wurde an den RW403B übertragen."
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
}
