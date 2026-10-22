import AppKit
import LabelCore
import SwiftUI

struct DashboardView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject var bluetooth: BluetoothPrinterService
    @ObservedObject var jobStore: PrintJobStore

    private var selectedJob: PrintJob? {
        if let id = appStore.selectedJobID,
           let match = jobStore.jobs.first(where: { $0.id == id }) {
            return match
        }
        return jobStore.jobs.first(where: { $0.status == .ready || $0.status == .failed })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                connectionCard
                formatCard
                importCard
                if let message = appStore.lastMessage {
                    Label(message, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(28)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .navigationTitle("Drucken")
    }

    private var formatCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "rectangle.and.pencil.and.ellipsis")
                .font(.system(size: 22))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34)
            LabelFormatControls(appStore: appStore)
            Spacer()
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Etiketten ohne Umweg")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            Text("Format wählen und Etsy-Bestellungen, PDF oder Bild direkt per Bluetooth drucken.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: bluetooth.connectionState.isReady ? "printer.fill" : "wave.3.right")
                    .font(.system(size: 24))
                    .foregroundStyle(bluetooth.connectionState.isReady ? Color.green : Color.accentColor)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text(bluetooth.connectionState.title)
                        .font(.headline)
                    if let detail = bluetooth.connectionState.detail {
                        Text(detail)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                if bluetooth.connectionState.isReady {
                    Button("Testetikett", action: appStore.printTestLabel)
                        .buttonStyle(.borderedProminent)
                    Button("Trennen", action: bluetooth.disconnect)
                } else {
                    Button("Geräte suchen", action: bluetooth.startScanning)
                        .buttonStyle(.borderedProminent)
                }
            }

            if !bluetooth.discoveredDevices.isEmpty && !bluetooth.connectionState.isReady {
                Divider()
                VStack(spacing: 8) {
                    ForEach(bluetooth.discoveredDevices.prefix(8)) { device in
                        HStack {
                            Image(systemName: device.looksLikeMunbyn ? "printer" : "dot.radiowaves.left.and.right")
                                .foregroundStyle(device.looksLikeMunbyn ? Color.accentColor : Color.secondary)
                            VStack(alignment: .leading) {
                                Text(device.name)
                                Text("Signal \(device.rssi) dBm")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Verbinden") {
                                bluetooth.connect(to: device.id)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }

            if bluetooth.transferProgress > 0 && bluetooth.transferProgress < 1 {
                ProgressView(value: bluetooth.transferProgress)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var importCard: some View {
        VStack(spacing: 18) {
            if let job = selectedJob {
                HStack(spacing: 18) {
                    preview(for: job.sourceURL)
                        .frame(width: 150, height: 190)

                    VStack(alignment: .leading, spacing: 9) {
                        Text(job.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text("\(job.resolvedLabelFormat.sizeDescription) · 203 dpi · \(job.status.label)")
                            .foregroundStyle(.secondary)
                        if let error = job.errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.callout)
                        }
                        HStack {
                            Button("Etikett drucken") {
                                appStore.printJob(job)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!bluetooth.connectionState.isReady || job.status == .printing)

                            Button("Andere Datei …") {
                                appStore.showImporter = true
                            }
                        }
                    }
                    Spacer()
                }
            } else {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary)
                Text("PDF, Bild oder Etsy-CSV hier ablegen")
                    .font(.title3.weight(.medium))
                Text("Dateien werden auf das gewählte Format eingepasst. Etsy-CSV-Dateien öffnen die Bestellauswahl.")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("PDF oder Bild …") {
                        appStore.showImporter = true
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Etsy-Bestellungen …") {
                        appStore.showEtsyImporter = true
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 250)
        .padding(24)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [7]))
                .foregroundStyle(.tertiary)
        }
        .dropDestination(for: URL.self) { urls, _ in
            appStore.importFiles(urls)
            return !urls.isEmpty
        }
    }

    @ViewBuilder
    private func preview(for url: URL) -> some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(8)
                .background(.white, in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "doc")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
    }
}
