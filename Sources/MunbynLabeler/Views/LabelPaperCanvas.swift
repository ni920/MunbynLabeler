import AppKit
import LabelCore
import SwiftUI

/// White is the physical label, independent of the surrounding macOS appearance.
struct LabelPaperCanvas: View {
    var image: NSImage?
    var placeholder: String? = nil
    var raster = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary.opacity(0.45))
            if let image {
                Image(nsImage: image)
                    .interpolation(raster ? .none : .high)
                    .resizable().scaledToFit()
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    .padding(24)
                    .accessibilityLabel("Etikettenvorschau")
            } else if let placeholder {
                VStack(spacing: 10) {
                    Image(systemName: "envelope").font(.title2).accessibilityHidden(true)
                    Text(placeholder).font(.callout)
                }.padding(24)
            } else {
                ProgressView("Vorschau wird erstellt …")
            }
        }
    }
}

struct AddressLayoutPreview: View {
    @ObservedObject var appStore: AppStore
    @State private var image: NSImage?
    @State private var error: String?

    private struct Input: Equatable {
        var recipient: RecipientAddress
        var sender: SenderAddress
        var format: LabelFormat
        var continuous: Bool
    }
    private var input: Input {
        Input(recipient: appStore.recipientAddress, sender: appStore.senderAddress, format: appStore.selectedLetterLabelFormat, continuous: appStore.labelStockMode == .continuous100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Dein Adressetikett").font(.headline)
                Spacer()
                Text(appStore.printedLabelFormat(input.format).sizeDescription).font(.callout).foregroundStyle(.secondary)
            }
            LabelPaperCanvas(image: image, placeholder: error ?? "Gib eine Empfängeradresse ein.")
                .frame(height: 190)
        }
        .onAppear(perform: render)
        .onChange(of: input) { _, _ in render() }
    }

    private func render() {
        image = nil; error = nil
        guard input.recipient.isComplete, input.sender.isComplete else { return }
        do {
            // In-memory PDF only: typing never adds jobs, files or stamp reservations.
            let data = try EtsyAddressLabelWriter.makePDFData(recipient: input.recipient, sender: input.sender, format: input.format)
            let raster = try LabelRenderer.render(pdfData: data, format: input.format)
            image = LabelPreviewRenderer.image(from: appStore.applyingMaterialCutGuide(to: raster))
            if image == nil { error = "Die Vorschau konnte nicht erstellt werden." }
        } catch { self.error = error.localizedDescription }
    }
}
