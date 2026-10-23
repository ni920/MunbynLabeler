import AppKit
import LabelCore
import SwiftUI

struct PrintPreviewView: View {
    @ObservedObject var appStore: AppStore
    let job: PrintJob

    @State private var previewImage: NSImage?
    @State private var previewError: String?

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
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

                LabeledContent("Format", value: job.resolvedLabelFormat.sizeDescription)
                if job.resolvedLabelFormat.id == LabelFormat.continuousLetter100x55.id {
                    LabeledContent("Material", value: "Endlosrolle")
                    Label("Nach dem Druck an der Abrisskante manuell trennen.", systemImage: "scissors")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Auflösung", value: "203 dpi")
                LabeledContent("Druckdichte", value: "\(appStore.density)")
                LabeledContent("Geschwindigkeit", value: "\(appStore.speed)")

                Text("Die Vorschau zeigt die schwarz-weißen Rasterdaten, die an den RW403B übertragen werden.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let previewError {
                    Label(previewError, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                } else if !appStore.bluetooth.connectionState.isReady {
                    Label("Zum Drucken zuerst den RW403B verbinden.", systemImage: "wave.3.right")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack {
                    Button("Schließen", role: .cancel) {
                        appStore.closePrintPreview()
                    }
                    Spacer()
                    Button("Jetzt drucken") {
                        appStore.printFromPreview(job)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(previewImage == nil || previewError != nil || !appStore.bluetooth.connectionState.isReady)
                }
            }
            .frame(width: 245)
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 570)
        .onAppear(perform: renderPreview)
    }

    @ViewBuilder
    private var previewCanvas: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.quaternary.opacity(0.35))

            if let previewImage {
                Image(nsImage: previewImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .background(.white)
                    .shadow(color: .black.opacity(0.16), radius: 14, y: 5)
                    .padding(26)
            } else if previewError == nil {
                ProgressView("Druckdaten werden gerastert …")
            }
        }
    }

    private func renderPreview() {
        do {
            let raster = try LabelRenderer.render(url: job.sourceURL, format: job.resolvedLabelFormat)
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
