import AppKit
import LabelCore
import SwiftUI

struct PostagePrintBatch: Identifiable {
    let id = UUID()
    let jobs: [PrintJob]
}

struct PostageBundleView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject var store: PostageStampStore
    @AppStorage("postageLabelFormatID") private var formatID = LabelFormat.shipping100x150.id
    @AppStorage("postageCutGuides") private var cutGuides = true
    @State private var releaseEntry: PostageStampStore.Entry?
    @State private var copiedSelection = false

    private var format: LabelFormat { appStore.postageFormat(for: formatID) }
    private var selected: [PostageStamp] {
        store.entries.filter { appStore.selectedPostageIDs.contains($0.id) && $0.status == .available }.map(\.stamp)
    }
    private var layout: PostageSheetLayout { PostageSheetLayout(stampSizes: selected.map { $0.sourceRect.size }, format: format) }
    private var busy: Bool { appStore.printInProgress || appStore.printingPostageBatch }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Briefmarkenbestand").font(.title2.weight(.semibold))
                    Text("Mehrere Internetmarken in Originalgröße auf einem Etikett.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("PDF-Bündel importieren …") { appStore.showPostageImporter = true }
                    .disabled(busy)
            }
            HStack {
                PostageFormatControls(appStore: appStore, formatID: $formatID)
                Toggle("Schnittlinien", isOn: $cutGuides)
                Spacer()
            }.disabled(busy)
            if store.entries.isEmpty {
                ContentUnavailableView("Briefmarken-PDF auswählen", systemImage: "rectangle.stack",
                    description: Text("Die App erkennt die einzelnen Marken im Bündel und ordnet deine Auswahl platzsparend an."))
            } else {
                HStack {
                    Button("Alle auswählen") { appStore.selectedPostageIDs = Set(store.entries.filter { $0.status == .available }.map(\.id)) }
                    Button("Keine") { appStore.selectedPostageIDs = [] }
                    Button(copiedSelection ? "Nummern kopiert" : "Nummern kopieren") {
                        copiedSelection = copyTrackingNumbers(selected)
                    }
                    .disabled(selected.isEmpty)
                    .help("Die vollständigen Sendungsnummern der Auswahl, jeweils in einer eigenen Zeile.")
                    .task(id: copiedSelection) {
                        guard copiedSelection else { return }
                        try? await Task.sleep(for: .seconds(2))
                        if !Task.isCancelled { copiedSelection = false }
                    }
                    Spacer()
                    Text("\(store.entries.filter { $0.status == .available }.count) verfügbar · \(store.entries.filter { $0.status == .printed }.count) gedruckt")
                        .foregroundStyle(.secondary)
                }.disabled(busy)
                List(store.entries) { entry in
                    HStack(spacing: 14) {
                        Toggle(isOn: Binding(
                            get: { appStore.selectedPostageIDs.contains(entry.id) && entry.status == .available },
                            set: { value in
                                if value { appStore.selectedPostageIDs.insert(entry.id) }
                                else { appStore.selectedPostageIDs.remove(entry.id) }
                            })) { Text("Marke \(entry.stamp.number) · \(entry.stamp.amount) €") }
                            .disabled(entry.status != .available || busy)
                        PostageTrackingNumberView(stamp: entry.stamp)
                        Spacer()
                        Text(entry.status.title).foregroundStyle(entry.status == .checkPrint ? .orange : .secondary)
                        if entry.status == .checkPrint {
                          if let flowID = entry.reservationID, let flow = appStore.letterFlows.flow(flowID) {
                            Button("Im Briefversand prüfen") { appStore.letterFlowPreview = flow }
                          } else {
                            Button("Als gedruckt markieren") { store.update([entry.id], status: .printed) }
                            Button("Freigeben …") { releaseEntry = entry }
                          }
                        }
                    }.padding(.vertical, 4)
                }
            }
            if appStore.printingPostageBatch {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(appStore.postageBatchProgress)
                    Spacer()
                    Button("Nach diesem Etikett stoppen", action: appStore.stopAfterCurrentPostageSheet)
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selected.isEmpty ? "Marken für den nächsten Druck auswählen" : "\(selected.count) Marken auf \(layout.sheets.count) Etikett\(layout.sheets.count == 1 ? "" : "en")")
                            .font(.headline)
                        if !selected.isEmpty { Text("Bis zu \(layout.capacity) Marken pro Etikett · Originalgröße 100 %").foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Button("Druckvorschau erstellen") { appStore.preparePostageSheets(format: format, cutGuides: cutGuides) }
                        .buttonStyle(.borderedProminent)
                        .disabled(selected.isEmpty || layout.capacity == 0 || busy)
                }
            }
            if let message = appStore.lastMessage { Text(message).font(.callout).foregroundStyle(.secondary) }
            if let message = store.storageError { Text(message).font(.callout).foregroundStyle(.red) }
            Text("Basis-Sendungsverfolgung: Bearbeitung im Briefzentrum, ohne Zustellnachweis.")
                .font(.caption).foregroundStyle(.secondary)
            PostageMaterialRequirement(appStore: appStore, bluetooth: appStore.bluetooth)
        }
        .padding(24)
        .navigationTitle("Briefmarken")
        .onChange(of: appStore.selectedPostageIDs) { _, _ in copiedSelection = false }
        .alert("Marke wieder zum Drucken freigeben?", isPresented: Binding(
            get: { releaseEntry != nil }, set: { if !$0 { releaseEntry = nil } }
        )) {
            Button("Abbrechen", role: .cancel) { releaseEntry = nil }
            Button("Freigeben") {
                if let entry = releaseEntry { store.update([entry.id], status: .available) }
                releaseEntry = nil
            }
        } message: { Text("Nur freigeben, wenn der letzte Ausdruck dieser Marke nicht verwendbar ist. Jede gekaufte Marke darf einmal für eine Sendung verwendet werden.") }
    }
}

struct PostagePrintPreviewView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject var bluetooth: BluetoothPrinterService
    let batch: PostagePrintBatch
    @State private var index = 0
    @State private var image: NSImage?
    @State private var error: String?
    @State private var copiedSheet = false

    private var sheetStamps: [PostageStamp] {
        (batch.jobs[index].postageStampIDs ?? []).compactMap { id in
            appStore.postage.entries.first { $0.id == id }?.stamp
        }
    }

    var body: some View {
        HStack(spacing: 24) {
            LabelPaperCanvas(image: image, placeholder: error)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 16) {
                Text("Briefmarken-Vorschau").font(.title2.bold())
                Text("\(batch.jobs.flatMap { $0.postageStampIDs ?? [] }.count) Marken auf \(batch.jobs.count) Etikett\(batch.jobs.count == 1 ? "" : "en")")
                Text(appStore.printedLabelFormat(batch.jobs[index].resolvedLabelFormat).sizeDescription).foregroundStyle(.secondary)
                if appStore.labelStockMode == .continuous100 {
                    Text("Schnittlinie unter jedem Etikett · 2 mm Zugabe").font(.callout)
                }
                Text("Originalgröße 100 %\nDie Marken nach dem Druck an den Schnittlinien trennen.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button { index -= 1 } label: { Label("Vorheriges Etikett", systemImage: "chevron.left").labelStyle(.iconOnly) }.disabled(index == 0)
                    Text("Etikett \(index + 1) / \(batch.jobs.count)")
                    Button { index += 1 } label: { Label("Nächstes Etikett", systemImage: "chevron.right").labelStyle(.iconOnly) }.disabled(index + 1 == batch.jobs.count)
                }
                Text("Sendungsnummern").font(.headline)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(sheetStamps) { stamp in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Marke \(stamp.number) · \(stamp.amount) €").font(.caption).foregroundStyle(.secondary)
                                PostageTrackingNumberView(stamp: stamp, showTitle: false)
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: 170)
                Button(copiedSheet ? "Nummern kopiert" : "Nummern dieses Etiketts kopieren") {
                    copiedSheet = copyTrackingNumbers(sheetStamps)
                }.disabled(sheetStamps.isEmpty)
                .task(id: copiedSheet) {
                    guard copiedSheet else { return }
                    try? await Task.sleep(for: .seconds(2))
                    if !Task.isCancelled { copiedSheet = false }
                }
                if let error { Text(error).foregroundStyle(.red) }
                PostageMaterialRequirement(appStore: appStore, bluetooth: bluetooth)
                if !bluetooth.connectionState.isReady { PrinterConnectionView(appStore: appStore, bluetooth: bluetooth) }
                Spacer()
                Button("Schließen", role: .cancel) { appStore.postagePreview = nil }
                Button(batch.jobs.count == 1 ? "Etikett drucken" : "Alle \(batch.jobs.count) Etiketten drucken") {
                    appStore.printPostageSheets(batch)
                }
                .buttonStyle(.borderedProminent)
                .disabled(image == nil || error != nil || !bluetooth.connectionState.isReady || !appStore.canPrintSelectedMaterialOverBluetooth || appStore.printInProgress)
            }.frame(width: 270)
        }
        .padding(24).frame(minWidth: 800, minHeight: 600)
        .onAppear(perform: render)
        .onChange(of: index) { _, _ in copiedSheet = false; render() }
        .onChange(of: appStore.labelStockMode) { _, _ in render() }
    }

    private func render() {
        image = nil; error = nil
        do {
            let job = batch.jobs[index]
            let raster = try appStore.renderLabel(job)
            image = LabelPreviewRenderer.image(from: raster)
        } catch { self.error = error.localizedDescription }
    }
}

struct PostageTrackingNumberView: View {
    let stamp: PostageStamp
    var showTitle = true
    @State private var copied = false

    var body: some View {
        if let number = stamp.trackingNumber {
            VStack(alignment: .leading, spacing: 3) {
                if showTitle { Text("Sendungsnummer").font(.caption).foregroundStyle(.secondary) }
                HStack(spacing: 6) {
                    Text(number).font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    Button {
                        copied = copyTrackingNumbers([stamp])
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Sendungsnummer von Marke \(stamp.number) kopieren")
                    .help(copied ? "Sendungsnummer kopiert" : "Vollständige Sendungsnummer kopieren")
                }
            }
            .task(id: copied) {
                guard copied else { return }
                try? await Task.sleep(for: .seconds(2))
                if !Task.isCancelled { copied = false }
            }
        }
    }
}

@MainActor
@discardableResult
func copyTrackingNumbers(_ stamps: [PostageStamp]) -> Bool {
    let value = PostageStamp.trackingNumbersText(for: stamps)
    guard !value.isEmpty else { return false }
    NSPasteboard.general.clearContents()
    return NSPasteboard.general.setString(value, forType: .string)
}
