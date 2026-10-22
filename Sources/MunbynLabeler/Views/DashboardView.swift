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
                ShippingFormView(appStore: appStore)
                if let selectedJob {
                    readyLabelCard(selectedJob)
                }
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Etiketten ohne Umweg")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            Text("Briefadresse eingeben oder ein fertiges DHL-Paketlabel auswählen und direkt drucken.")
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

    private func readyLabelCard(_ job: PrintJob) -> some View {
        HStack(spacing: 18) {
            preview(for: job.sourceURL)
                .frame(width: 130, height: 160)

            VStack(alignment: .leading, spacing: 9) {
                Label("Druckbereit", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
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
                Button("Druckvorschau") {
                    appStore.presentPrintPreview(job)
                }
                .buttonStyle(.borderedProminent)
                .disabled(job.status == .printing)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
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
