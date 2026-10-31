import AppKit
import LabelCore
import SwiftUI

struct PostagePrintBatch: Identifiable {
    let id = UUID()
    let jobs: [PrintJob]
}

enum PostageStockFilter: String, CaseIterable, Identifiable {
    case available, used, all
    var id: Self { self }
    var title: String {
        switch self {
        case .available: "Verfügbar"
        case .used: "Genutzt"
        case .all: "Alle"
        }
    }
    func includes(_ entry: PostageStampStore.Entry) -> Bool {
        switch self {
        case .available: !entry.isUsed
        case .used: entry.isUsed
        case .all: true
        }
    }
}

struct PostageBundleView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject var store: PostageStampStore
    @AppStorage("postageLabelFormatID") private var formatID = LabelFormat.shipping100x150.id
    @AppStorage("postageCutGuides") private var cutGuides = true
    @State private var releaseEntry: PostageStampStore.Entry?
    @State private var markUsedIDs: Set<String> = []
    @State private var deleteIDs: Set<String> = []
    @State private var filter: PostageStockFilter = .available
    @State private var copiedSelection = false

    private var format: LabelFormat { appStore.postageFormat(for: formatID) }
    private var selectedEntries: [PostageStampStore.Entry] {
        store.entries.filter { appStore.selectedPostageIDs.contains($0.id) && $0.status == .available }
    }
    private var selectedIDs: Set<String> { Set(selectedEntries.map(\.id)) }
    private var selected: [PostageStamp] {
        selectedEntries.map(\.stamp)
    }
    private var layout: PostageSheetLayout { PostageSheetLayout(stampSizes: selected.map { $0.sourceRect.size }, format: format) }
    private var busy: Bool { appStore.printInProgress || appStore.printingPostageBatch }
    private var visibleEntries: [PostageStampStore.Entry] { store.entries.filter(filter.includes) }
    private var availableCount: Int { store.entries.filter { $0.status == .available }.count }
    private var usedCount: Int { store.entries.filter(\.isUsed).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Drucklayout")
                    .font(.headline)
                HStack(alignment: .bottom, spacing: 20) {
                    PostageFormatControls(appStore: appStore, formatID: $formatID)
                    Toggle("Schnittlinien", isOn: $cutGuides)
                }
            }
            .disabled(busy)

            if store.entries.isEmpty {
                ContentUnavailableView {
                    Label("Noch keine Briefmarken", systemImage: "rectangle.stack")
                } description: {
                    Text("Importiere ein PDF-Bündel. Die App erkennt die Marken und ordnet deine Auswahl platzsparend an.")
                } actions: {
                    Button("PDF-Bündel importieren …") {
                        appStore.showPostageImporter = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(busy)
                }
            } else {
                HStack(alignment: .center) {
                    Picker("Anzeigen", selection: $filter) {
                        ForEach(PostageStockFilter.allCases) { option in
                            Text(count(for: option)).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 420)
                    Spacer()
                    Text("\(availableCount) verfügbar · \(usedCount) genutzt")
                        .foregroundStyle(.secondary)
                }
                if visibleEntries.isEmpty {
                    ContentUnavailableView(filter == .used ? "Noch keine Marke genutzt" : "Keine verfügbaren Marken",
                        systemImage: filter == .used ? "clock.arrow.circlepath" : "rectangle.stack",
                        description: Text(filter == .used ? "Gedruckte Marken erscheinen hier mit Druckdatum und lassen sich nach einem Fehldruck erneut verwenden." : "Neues PDF-Bündel importieren oder unter „Genutzt“ eine fehlgedruckte Marke erneut verwenden."))
                } else {
                    List(visibleEntries) { entry in row(entry) }
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
        .task(id: copiedSelection) {
            guard copiedSelection else { return }
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { copiedSelection = false }
        }
        .toolbar {
            if availableCount > 0 {
                ToolbarItem {
                    Menu {
                        selectionActions
                    } label: {
                        Label(selected.isEmpty ? "Auswahl" : "Auswahl (\(selected.count))", systemImage: "checkmark.circle")
                    }
                    .disabled(busy)
                    .help("Verfügbare Briefmarken auswählen und verwalten")
                }
            }
        }
        .alert("Marke erneut verwenden?", isPresented: Binding(
            get: { releaseEntry != nil }, set: { if !$0 { releaseEntry = nil } }
        )) {
            Button("Abbrechen", role: .cancel) { releaseEntry = nil }
            Button("Erneut verwenden") {
                if let entry = releaseEntry, store.reuse([entry.id]) {
                    appStore.selectedPostageIDs.insert(entry.id)
                    filter = .available
                }
                releaseEntry = nil
            }
        } message: { Text("Nur verwenden, wenn der bisherige Ausdruck dieser Marke unbrauchbar ist und vernichtet wurde. Jede gekaufte Marke darf nur einmal für eine Sendung verwendet werden. Die Marke wird für den nächsten Druck ausgewählt.") }
        .alert(markUsedIDs.count == 1 ? "Briefmarke als genutzt markieren?" : "\(markUsedIDs.count) Briefmarken als genutzt markieren?", isPresented: Binding(
            get: { !markUsedIDs.isEmpty }, set: { if !$0 { markUsedIDs = [] } }
        )) {
            Button("Abbrechen", role: .cancel) { markUsedIDs = [] }
            Button("Als genutzt markieren", action: markSelectedUsed)
        } message: { Text("Zum Beispiel, wenn die Marke außerhalb der App gedruckt wurde. Sie wird danach nicht mehr zum Drucken angeboten.") }
        .alert(deleteIDs.count == 1 ? "Briefmarke löschen?" : "\(deleteIDs.count) Briefmarken löschen?", isPresented: Binding(
            get: { !deleteIDs.isEmpty }, set: { if !$0 { deleteIDs = [] } }
        )) {
            Button("Abbrechen", role: .cancel) { deleteIDs = [] }
            Button(deleteIDs.count == 1 ? "Briefmarke löschen" : "Briefmarken löschen", role: .destructive, action: deleteSelected)
        } message: {
            Text("Die Auswahl wird dauerhaft aus dem Bestand entfernt. Ein erneuter Import des PDF-Bündels fügt die Marken wieder hinzu.")
        }
    }

    private func count(for option: PostageStockFilter) -> String {
        switch option {
        case .available: "Verfügbar (\(availableCount))"
        case .used: "Genutzt (\(usedCount))"
        case .all: "Alle (\(store.entries.count))"
        }
    }

    /// A stamp tied to an unfinished letter flow must be resolved there, so
    /// address and stamp progress stay consistent.
    private func pendingLetterFlow(for entry: PostageStampStore.Entry) -> LetterShipmentFlow? {
        guard let id = entry.reservationID, let flow = appStore.letterFlows.flow(id), flow.stage != .completed else { return nil }
        return flow
    }

    @ViewBuilder
    private func row(_ entry: PostageStampStore.Entry) -> some View {
        HStack(spacing: 14) {
            Toggle(isOn: Binding(
                get: { appStore.selectedPostageIDs.contains(entry.id) && entry.status == .available },
                set: { value in
                    if value { appStore.selectedPostageIDs.insert(entry.id) }
                    else { appStore.selectedPostageIDs.remove(entry.id) }
                })) { Text("Marke \(entry.stamp.number) · \(entry.stamp.amount) €") }
                .disabled(entry.status != .available || busy)
            PostageTrackingNumberView(stamp: entry.stamp, showsCopyButton: false)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.status.title).foregroundStyle(entry.status == .checkPrint ? .orange : .secondary)
                if let detail = usageDetail(entry) {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Menu {
                entryActions(for: entry)
            } label: {
                Label("Weitere Aktionen", systemImage: "ellipsis")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Aktionen für Marke \(entry.stamp.number)")
        }
        .padding(.vertical, 4)
        .disabled(busy)
        .contextMenu {
            entryActions(for: entry)
        }
    }

    @ViewBuilder
    private var selectionActions: some View {
        Button {
            appStore.selectedPostageIDs = Set(store.entries.filter { $0.status == .available }.map(\.id))
        } label: {
            Label("Alle verfügbaren auswählen", systemImage: "checkmark.circle")
        }
        .disabled(selected.count == availableCount)

        Button {
            appStore.selectedPostageIDs = []
        } label: {
            Label("Auswahl aufheben", systemImage: "xmark.circle")
        }
        .disabled(selected.isEmpty)

        Divider()

        Button {
            copiedSelection = copyTrackingNumbers(selected)
        } label: {
            Label(copiedSelection ? "Nummern kopiert" : "Sendungsnummern kopieren", systemImage: copiedSelection ? "checkmark" : "doc.on.doc")
        }
        .disabled(selected.isEmpty)

        Button {
            markUsedIDs = selectedIDs
        } label: {
            Label("Als genutzt markieren …", systemImage: "checkmark.circle")
        }
        .disabled(selected.isEmpty)

        Divider()

        Button(role: .destructive) {
            deleteIDs = selectedIDs
        } label: {
            Label("Aus Bestand löschen …", systemImage: "trash")
        }
        .disabled(selected.isEmpty)
    }

    @ViewBuilder
    private func entryActions(for entry: PostageStampStore.Entry) -> some View {
        if let flow = pendingLetterFlow(for: entry), entry.status == .checkPrint || entry.status == .printed {
            Button {
                appStore.letterFlowPreview = flow
            } label: {
                Label("Im Briefversand prüfen", systemImage: "envelope")
            }
        } else {
            if entry.status == .checkPrint {
                Button {
                    markPrinted(entry)
                } label: {
                    Label("Als gedruckt markieren", systemImage: "checkmark.circle")
                }
            }
            if entry.status == .printed || entry.status == .checkPrint {
                Button {
                    releaseEntry = entry
                } label: {
                    Label("Erneut verwenden …", systemImage: "arrow.uturn.backward")
                }
            }
        }

        if entry.stamp.trackingNumber != nil {
            Button {
                copyTrackingNumbers([entry.stamp])
            } label: {
                Label("Sendungsnummer kopieren", systemImage: "doc.on.doc")
            }
        }

        if entry.status == .available {
            Button {
                markUsedIDs = [entry.id]
            } label: {
                Label("Als genutzt markieren …", systemImage: "checkmark.circle")
            }
            Divider()
            Button(role: .destructive) {
                deleteIDs = [entry.id]
            } label: {
                Label("Aus Bestand löschen …", systemImage: "trash")
            }
        }
    }

    private func markPrinted(_ entry: PostageStampStore.Entry) {
        guard store.update([entry.id], status: .printed) else {
            appStore.lastMessage = store.storageError ?? "Die Marke konnte nicht als gedruckt markiert werden."
            return
        }
        appStore.lastMessage = "Briefmarke wurde als gedruckt markiert."
    }

    private func markSelectedUsed() {
        let ids = markUsedIDs
        defer { markUsedIDs = [] }
        guard ids.allSatisfy({ id in
            store.entries.contains { $0.id == id && $0.status == .available }
        }), store.update(Array(ids), status: .printed) else {
            appStore.lastMessage = store.storageError ?? "Die Auswahl konnte nicht als genutzt markiert werden."
            return
        }
        clearSelectionReferences(to: ids)
        appStore.lastMessage = ids.count == 1
            ? "Briefmarke wurde als genutzt markiert."
            : "\(ids.count) Briefmarken wurden als genutzt markiert."
    }

    private func deleteSelected() {
        let ids = deleteIDs
        defer { deleteIDs = [] }
        guard store.delete(Array(ids)) else {
            appStore.lastMessage = store.storageError ?? "Die Auswahl konnte nicht gelöscht werden."
            return
        }
        clearSelectionReferences(to: ids)
        appStore.lastMessage = ids.count == 1
            ? "Briefmarke wurde aus dem Bestand gelöscht."
            : "\(ids.count) Briefmarken wurden aus dem Bestand gelöscht."
    }

    private func clearSelectionReferences(to ids: Set<String>) {
        appStore.selectedPostageIDs.subtract(ids)
        if ids.contains(appStore.selectedLetterPostageID) {
            appStore.selectedLetterPostageID = ""
        }
    }

    private func usageDetail(_ entry: PostageStampStore.Entry) -> String? {
        var parts: [String] = []
        if entry.isUsed, let date = entry.printedAt {
            parts.append(date.formatted(date: .abbreviated, time: .shortened))
        }
        if let count = entry.printCount, count > 1 { parts.append("\(count)× gedruckt") }
        if entry.status == .available, entry.releasedAt != nil { parts.append("Nach Fehldruck freigegeben") }
        if let id = entry.reservationID, let flow = appStore.letterFlows.flow(id), !flow.recipientName.isEmpty {
            parts.append("Brief an \(flow.recipientName)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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
    var showsCopyButton = true
    @State private var copied = false

    var body: some View {
        if let number = stamp.trackingNumber {
            VStack(alignment: .leading, spacing: 3) {
                if showTitle { Text("Sendungsnummer").font(.caption).foregroundStyle(.secondary) }
                HStack(spacing: 6) {
                    Text(number).font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    if showsCopyButton {
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
