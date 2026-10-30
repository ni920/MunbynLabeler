import AppKit
import LabelCore
import SwiftUI

struct PrintPreviewView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject var bluetooth: BluetoothPrinterService
    let job: PrintJob

    init(appStore: AppStore, job: PrintJob) {
        self.appStore = appStore
        self.bluetooth = appStore.bluetooth
        self.job = job
    }

    @State private var previewImage: NSImage?
    @State private var previewError: String?

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            previewCanvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Druckvorschau")
                        .font(.title2.weight(.semibold))
                    Text(job.title)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Divider()

                LabeledContent("Druckformat", value: appStore.printedLabelFormat(job.resolvedLabelFormat).sizeDescription)
                if appStore.labelStockMode == .continuous100 {
                    LabeledContent("Material", value: "Endlosrolle")
                    Label(
                        bluetooth.supportsContinuousStock
                            ? "Bluetooth mit Firmware \(bluetooth.firmwareVersion ?? "1.1.49"). Mit Schnittlinie und 2 mm Zugabe."
                            : "Für Bluetooth den Drucker mit Firmware ab 1.1.49 verbinden. Alternativ über USB mit Medientyp Endlos/Continuous drucken.",
                        systemImage: "info.circle"
                    )
                        .font(.callout)
                }
                DisclosureGroup("Druckeinstellungen") {
                    LabeledContent("Auflösung", value: "203 dpi")
                    LabeledContent("Druckdichte", value: "\(appStore.density)")
                    LabeledContent("Geschwindigkeit", value: "\(appStore.speed)")
                }

                Text("Prüfe Adresse, Ausrichtung und Größe vor dem Drucken.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let previewError {
                    Label(previewError, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                } else if !bluetooth.connectionState.isReady {
                    PrinterConnectionView(appStore: appStore, bluetooth: bluetooth)
                }

                Spacer()

                HStack {
                    Button("Schließen", role: .cancel) {
                        appStore.closePrintPreview()
                    }
                    Spacer()
                    Button(appStore.canPrintSelectedMaterialOverBluetooth ? "Jetzt drucken" : "Über USB drucken") {
                        appStore.printFromPreview(job)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(
                        previewImage == nil
                            || previewError != nil
                            || appStore.printInProgress || appStore.printingPostageBatch
                            || (job.postageStampIDs.map { !appStore.postage.canPrint($0) } ?? false)
                            || (appStore.canPrintSelectedMaterialOverBluetooth
                                && !bluetooth.connectionState.isReady)
                    )
                }
            }
            .frame(width: 270)
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 570)
        .onAppear(perform: renderPreview)
        .onChange(of: appStore.labelStockMode) { _, _ in renderPreview() }
    }

    private var previewCanvas: some View {
        LabelPaperCanvas(image: previewImage, placeholder: previewError)
    }

    private func renderPreview() {
        do {
            let raster = try appStore.renderLabel(job)
            guard let image = LabelPreviewRenderer.image(from: raster) else {
                previewError = "Die Rastervorschau konnte nicht erstellt werden."
                return
            }
            previewImage = image
        } catch {
            previewError = error.localizedDescription
        }
    }
}
