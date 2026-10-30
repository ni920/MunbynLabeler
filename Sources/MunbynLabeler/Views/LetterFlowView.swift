import AppKit
import LabelCore
import SwiftUI

struct LetterFlowView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject var store: LetterFlowStore
    @ObservedObject var controller: LetterFlowController
    @ObservedObject var bluetooth: BluetoothPrinterService
    let initialFlow: LetterShipmentFlow
    @State private var step = 0
    @State private var image: NSImage?
    @State private var previewError: String?
    @State private var copied = false
    @State private var confirmStampRetry = false
    @AppStorage("letterFlowAutoCopyTracking") private var autoCopy = false

    private var flow: LetterShipmentFlow { store.flow(initialFlow.id) ?? initialFlow }
    private var active: Bool { controller.activeFlowID == flow.id }
    private var canStart: Bool {
        bluetooth.connectionState.isReady && appStore.canPrintSelectedMaterialOverBluetooth &&
        !appStore.printInProgress && !appStore.printingPostageBatch && controller.activeFlowID == nil && previewError == nil &&
        appStore.postage.canPrint([flow.stamp.id], reservationID: flow.id)
    }

    var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 12) {
                Picker("Vorschau", selection: $step) {
                    Text("1 · Adresse").tag(0)
                    Text("2 · Briefmarke").tag(1)
                }.pickerStyle(.segmented)
                LabelPaperCanvas(image: image, placeholder: previewError)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 14) {
                Text("Briefversand").font(.title2.bold())
                Text(flow.recipientName).font(.headline)
                if let order = flow.orderID { Text("Etsy #\(order)").foregroundStyle(.secondary) }
                Text("Adresse + \(flow.stamp.amount) € Briefmarke\n2 Etiketten · \(appStore.printedLabelFormat(flow.addressJob.resolvedLabelFormat).sizeDescription)")
                    .font(.callout).foregroundStyle(.secondary)
                if appStore.labelStockMode == .continuous100 {
                    Text("Mit Schnittlinie unter jedem Etikett · 2 mm Zugabe").font(.callout)
                }
                Divider()
                HStack {
                    if active { ProgressView().controlSize(.small) }
                    Text(flow.stage.title).font(.headline)
                }
                if let error = flow.errorMessage ?? controller.message ?? store.storageError {
                    Text(error).font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
                if let previewError { Text(previewError).font(.callout).foregroundStyle(.red) }
                Text("Sendungsnummer").font(.headline)
                PostageTrackingNumberView(stamp: flow.stamp, showTitle: false)
                if flow.stage == .ready || flow.stage == .addressPrinted {
                    Toggle("Nach Abschluss automatisch kopieren", isOn: $autoCopy).font(.callout)
                    PostageMaterialRequirement(appStore: appStore, bluetooth: bluetooth)
                    if !bluetooth.connectionState.isReady {
                        PrinterConnectionView(appStore: appStore, bluetooth: bluetooth)
                    }
                    if !appStore.postage.canPrint([flow.stamp.id], reservationID: flow.id) {
                        Text("Diese Briefmarke ist nicht mehr verfügbar. Bitte im Briefformular eine andere Marke auswählen und einen neuen Ablauf vorbereiten.")
                            .font(.callout).foregroundStyle(.orange)
                    }
                }
                if flow.stage == .completed {
                    Text("Beide Etiketten sind bestätigt. Die Sendungsnummer ist diesem Brief zugeordnet.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button(copied ? "Sendungsnummer kopiert" : "Sendungsnummer kopieren") {
                        copied = copyTrackingNumbers([flow.stamp])
                    }.buttonStyle(.borderedProminent)
                }
                Spacer(minLength: 8)
                actions
                Button(flow.stage == .completed ? "Fertig" : "Schließen", role: .cancel) { appStore.letterFlowPreview = nil }
                    .disabled(active)
            }.frame(width: 290)
        }
        .padding(24).frame(minWidth: 840, minHeight: 610)
        .interactiveDismissDisabled(active)
        .onAppear {
            if [.addressPrinted, .printingStamp, .stampCheck, .completed].contains(flow.stage) { step = 1 }
            render()
        }
        .onChange(of: step) { _, _ in render() }
        .onChange(of: appStore.labelStockMode) { _, _ in render() }
        .onChange(of: flow.stage) { _, stage in
            if stage == .printingStamp || stage == .completed { step = 1 }
            if stage == .completed && autoCopy { copied = copyTrackingNumbers([flow.stamp]) }
        }
        .alert("Nur die Briefmarke erneut drucken?", isPresented: $confirmStampRetry) {
            Button("Abbrechen", role: .cancel) {}
            Button("Briefmarke erneut drucken") { controller.resolveStamp(flow.id, alreadyPrinted: false) }
        } message: { Text("Bitte nur fortsetzen, wenn der vorherige Briefmarkenausdruck unbrauchbar ist. Die Adresse wird dabei nicht erneut gedruckt.") }
    }

    @ViewBuilder private var actions: some View {
        switch flow.stage {
        case .ready, .addressPrinted:
            Button(flow.stage == .ready ? "Adresse + Briefmarke drucken" : "Nur Briefmarke drucken") { controller.start(flow.id) }
                .buttonStyle(.borderedProminent).disabled(!canStart)
        case .addressCheck:
            Text("Ist die Adresse bereits korrekt gedruckt?").font(.callout)
            Button("Ja · nur Briefmarke drucken") { controller.resolveAddress(flow.id, alreadyPrinted: true) }
                .disabled(controller.activeFlowID != nil)
            Button("Nein · Adresse erneut drucken") { controller.resolveAddress(flow.id, alreadyPrinted: false) }
                .disabled(controller.activeFlowID != nil)
        case .stampCheck:
            Text("Bitte den letzten Briefmarkenausdruck prüfen.").font(.callout)
            Button("Marke ist korrekt gedruckt") { controller.resolveStamp(flow.id, alreadyPrinted: true) }
                .disabled(controller.activeFlowID != nil)
            Button("Marke ist unbrauchbar …") { confirmStampRetry = true }.disabled(controller.activeFlowID != nil)
        case .printingAddress, .printingStamp, .completed:
            EmptyView()
        }
    }

    private func render() {
        image = nil; previewError = nil
        let job = step == 0 ? flow.addressJob : flow.stampJob
        do { image = LabelPreviewRenderer.image(from: try appStore.renderLabel(job)) }
        catch { previewError = error.localizedDescription }
    }
}

struct LetterFlowHistoryView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject var store: LetterFlowStore

    var body: some View {
        Group {
            if store.flows.isEmpty {
                ContentUnavailableView("Noch kein Briefablauf", systemImage: "envelope",
                    description: Text(store.storageError ?? "Unter Versenden einen Brief mit Adresse und Briefmarke vorbereiten."))
            } else {
                List(store.flows) { flow in
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(flow.recipientName).font(.headline)
                            if let order = flow.orderID { Text("Etsy #\(order)").font(.caption).foregroundStyle(.secondary) }
                            Text(flow.stage.title).font(.callout).foregroundStyle(flow.stage == .completed ? .green : .secondary)
                            Text(flow.createdAt.formatted(.dateTime.day().month().hour().minute())).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        PostageTrackingNumberView(stamp: flow.stamp)
                        Button(flow.stage == .completed ? "Anzeigen" : "Öffnen / fortsetzen") { appStore.letterFlowPreview = flow }
                    }.padding(.vertical, 6)
                }
            }
        }.navigationTitle("Briefverlauf")
    }
}
