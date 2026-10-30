import LabelCore
import SwiftUI

struct GuidedShippingView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject var postage: PostageStampStore
    @ObservedObject var jobs: PrintJobStore
    @ObservedObject var controller: LetterFlowController
    @Binding var journey: GuidedShippingJourney
    @AppStorage("postageLabelFormatID") private var postageFormatID = LabelFormat.shipping100x150.id
    @AppStorage("postageCutGuides") private var cutGuides = true

    private var postageFormat: LabelFormat { appStore.postageFormat(for: postageFormatID) }
    private var available: [PostageStamp] { postage.entries.filter { $0.status == .available }.map(\.stamp) }
    private var selected: [PostageStamp] { available.filter { appStore.selectedPostageIDs.contains($0.id) } }
    private var letterStamp: PostageStamp? { available.first { $0.id == appStore.selectedLetterPostageID } }
    private var parcel: PrintJob? { jobs.jobs.first { $0.id == journey.parcelJobID } }
    private var busy: Bool { appStore.printInProgress || appStore.printingPostageBatch || controller.activeFlowID != nil }
    private var layout: PostageSheetLayout { PostageSheetLayout(stampSizes: selected.map { $0.sourceRect.size }, format: postageFormat) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let task = journey.task, let step = journey.step {
                    stepHeader(task: task, step: step)
                    if let validation {
                        Label(validation, systemImage: "info.circle")
                            .font(.callout).fixedSize(horizontal: false, vertical: true)
                        if let correction = validationCorrection, correction != step {
                            Button("\(correction.title) bearbeiten") { journey.goBack(to: correction) }
                                .disabled(busy)
                        }
                    }
                    stepContent(step)
                    if busy { Label("Ein Druckablauf läuft. Bitte warte auf den Abschluss.", systemImage: "printer") }
                    Button("Andere Aufgabe auswählen") { journey.reset() }
                        .buttonStyle(.link).disabled(busy)
                } else {
                    ShippingTaskPicker(disabled: busy) { task in
                        journey.choose(task)
                        appStore.selectedShipmentKind = task == .parcel ? .parcel : .letter
                        appStore.lastMessage = nil
                    }
                }
                if let message = appStore.lastMessage {
                    Label(message, systemImage: "info.circle")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            .padding(32)
            .frame(maxWidth: journey.step == .recipient ? 1_000 : 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle(journey.task?.title ?? "Versenden")
        .toolbar {
            if journey.task != nil {
                ToolbarItem(placement: .navigation) {
                    Button { journey.back() } label: { Label("Zurück", systemImage: "chevron.left") }
                        .help("Zum vorherigen Schritt").disabled(busy)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(journey.nextStep == nil ? "Vorschau" : "Weiter", action: advance)
                        .buttonStyle(.borderedProminent)
                        .help(journey.nextStep.map { "Weiter: \($0.title)" } ?? "Druckvorschau öffnen")
                        .disabled(validation != nil || busy)
                }
            }
        }
        .focusedSceneValue(\.shippingNavigation, journey.task == nil ? nil : ShippingNavigationActions(
            back: { journey.back() }, advance: advance, canGoBack: !busy, canAdvance: validation == nil && !busy
        ))
    }

    private func stepHeader(task: GuidedShippingJourney.Task, step: GuidedShippingJourney.Step) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(task.title, systemImage: task.icon).font(.callout)
                Spacer()
                Text("Schritt \(journey.index + 1) von \(task.steps.count)").font(.callout)
            }
            ProgressView(value: Double(journey.index + 1), total: Double(task.steps.count))
                .accessibilityLabel("Fortschritt")
                .accessibilityValue("Schritt \(journey.index + 1) von \(task.steps.count)")
            Text(step.title).font(.system(size: 20, weight: .semibold))
        }
    }

    private func advance() {
        guard validation == nil, !busy else { return }
        if journey.nextStep != nil { journey.advance() } else { openPreview() }
    }

    @ViewBuilder private func stepContent(_ step: GuidedShippingJourney.Step) -> some View {
        switch step {
        case .recipient:
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) {
                    recipientFields.frame(width: 400)
                    AddressLayoutPreview(appStore: appStore).frame(width: 280)
                }
                VStack(alignment: .leading, spacing: 24) {
                    recipientFields
                    AddressLayoutPreview(appStore: appStore)
                }
            }
        case .franking:
            GroupBox {
              VStack(alignment: .leading, spacing: 18) {
                Picker("Was soll gedruckt werden?", selection: $appStore.letterWithPostage) {
                    Text("Nur Adressetikett").tag(false)
                    Text("Adresse und Briefmarke").tag(true)
                }.pickerStyle(.radioGroup)
                if appStore.letterWithPostage {
                    Text("Wähle eine gekaufte Marke mit dem passenden Portowert. Nach dem Druck steht ihre Sendungsnummer zum Kopieren bereit.")
                    Picker("Briefmarke", selection: $appStore.selectedLetterPostageID) {
                        Text("Bitte auswählen …").tag("")
                        ForEach(available) { stamp in Text("\(stamp.amount) € · …\(stamp.id.suffix(8))").tag(stamp.id) }
                    }
                    Button("Briefmarken-PDF importieren …") { appStore.showPostageImporter = true }
                    if available.isEmpty { Text("Im Bestand ist noch keine verfügbare Briefmarke.") }
                }
              }.padding(12)
            }
        case .format:
            if journey.task == .postage {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Wähle das Format der eingelegten Etiketten. Die Marken bleiben in Originalgröße.")
                    PostageFormatControls(appStore: appStore, formatID: $postageFormatID)
                    Toggle("Schnittlinien drucken", isOn: $cutGuides)
                    Text("\(selected.count) Marken auf \(layout.sheets.count) Etikett\(layout.sheets.count == 1 ? "" : "en") · bis zu \(layout.capacity) pro Etikett")
                    PostageMaterialRequirement(appStore: appStore, bluetooth: appStore.bluetooth)
                }
            } else {
                GroupBox {
                  VStack(alignment: .leading, spacing: 18) {
                    Text(appStore.letterWithPostage ? "Adresse und Briefmarke verwenden dasselbe Etikettenformat." : "Wähle das Format der eingelegten Etiketten. Deine Auswahl wird gespeichert.")
                    LabelFormatControls(appStore: appStore, showHeading: false)
                  }.padding(12)
                }
                AddressLayoutPreview(appStore: appStore)
            }
        case .parcelFile:
            VStack(alignment: .leading, spacing: 18) {
                Text("Kaufe dein Versandlabel bei DHL und wähle anschließend die heruntergeladene PDF aus. Die Lieferadresse ist bereits enthalten.")
                Label("Paketlabel: 100 × 150 mm", systemImage: "rectangle.portrait")
                Button(parcel == nil ? "DHL-PDF auswählen …" : "Andere Datei auswählen …", action: appStore.chooseDHLLabelImport)
                if let parcel { Label(parcel.title, systemImage: "doc") }
            }
        case .postageSource:
            VStack(alignment: .leading, spacing: 18) {
                Text("Importiere ein gekauftes PDF-Bündel mit Internetmarken ohne Motiv und Adresse. Bereits importierte Marken bleiben im Bestand erhalten.")
                Button("Briefmarken-PDF importieren …") { appStore.showPostageImporter = true }
                Text("\(available.count) Marken im Bestand verfügbar. Über Weiter kannst du vorhandene Marken auswählen.")
            }
        case .postageSelection:
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("\(selected.count) von \(available.count) ausgewählt").font(.headline)
                    Spacer()
                    Button("Alle") { appStore.selectedPostageIDs = Set(available.map(\.id)) }
                    Button("Keine") { appStore.selectedPostageIDs = [] }
                }
                ForEach(available) { stamp in
                    Toggle("\(stamp.amount) € · Marke \(stamp.number) · …\(stamp.id.suffix(8))", isOn: Binding(
                        get: { appStore.selectedPostageIDs.contains(stamp.id) },
                        set: { if $0 { appStore.selectedPostageIDs.insert(stamp.id) } else { appStore.selectedPostageIDs.remove(stamp.id) } }
                    )).padding(.vertical, 5)
                }
                Button("Weiteres Briefmarken-PDF importieren …") { appStore.showPostageImporter = true }
            }
        case .review:
            review
        }
    }

    private var recipientFields: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let order = appStore.activeBrowserOrder { Label("Etsy-Bestellung #\(order.orderID)", systemImage: "cart") }
            GroupBox { RecipientEditorView(appStore: appStore).padding(12) }
            Button("Aus Etsy-CSV übernehmen …") { appStore.showEtsyImporter = true }
            SenderSummaryView(appStore: appStore)
        }
    }

    @ViewBuilder private var review: some View {
        switch journey.task {
        case .letter:
            VStack(alignment: .leading, spacing: 20) {
                AddressLayoutPreview(appStore: appStore)
                GroupBox {
                  VStack(alignment: .leading, spacing: 12) {
                Text("Empfänger").font(.headline)
                Text(appStore.recipientAddress.lines.joined(separator: "\n")).textSelection(.enabled)
                Divider()
                SenderSummaryView(appStore: appStore)
                Divider()
                Label(appStore.printedLabelFormat(appStore.selectedLetterLabelFormat).sizeDescription, systemImage: "rectangle")
                if appStore.letterWithPostage, let stamp = letterStamp {
                    Text("1. Adressetikett · 2. Briefmarke mit \(stamp.amount) €")
                    Text("Nach dem Druck kannst du die Sendungsnummer kopieren. Der Druck startet erst in der Vorschau.")
                } else if appStore.letterWithPostage {
                    Text("Adresse und Briefmarke sind gewählt. Bitte noch eine verfügbare Briefmarke mit passendem Portowert auswählen.")
                } else { Text("Ein Adressetikett. Die Briefmarke klebst du selbst auf.") }
                  }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case .parcel:
            if let parcel {
                VStack(alignment: .leading, spacing: 16) {
                    Label(parcel.title, systemImage: "doc")
                    Text("\(parcel.resolvedLabelFormat.sizeDescription) · \(parcel.status.label)")
                    Text("Prüfe Adresse und Barcodes im nächsten Fenster, bevor du druckst.")
                }
            }
        case .postage:
            VStack(alignment: .leading, spacing: 16) {
                Text("\(selected.count) Briefmarken auf \(layout.sheets.count) Etikett\(layout.sheets.count == 1 ? "" : "en")").font(.headline)
                Text("\(appStore.printedLabelFormat(postageFormat).sizeDescription) · Originalgröße 100 %")
                Text(cutGuides ? "Mit Schnittlinien zum Ausschneiden." : "Ohne Schnittlinien.")
                Text("In der Vorschau kannst du jedes Etikett und die zugehörigen Sendungsnummern prüfen.")
            }
        case nil: EmptyView()
        }
    }

    private var validation: String? {
        switch journey.task {
        case .letter:
            if !appStore.recipientAddress.isComplete { return "Bitte Name, Straße, Postleitzahl, Ort und Land des Empfängers ergänzen." }
            if !appStore.senderAddress.isComplete { return "Bitte zuerst den Absender in den Einstellungen vervollständigen." }
            if journey.step != .recipient && appStore.letterWithPostage {
                if letterStamp == nil { return "Bitte eine verfügbare Briefmarke mit passendem Portowert auswählen." }
                if journey.step != .franking {
                    if let stamp = letterStamp, PostageSheetLayout(stampSizes: [stamp.sourceRect.size], format: appStore.selectedLetterLabelFormat).capacity == 0 {
                        return "Die Briefmarke passt nicht in Originalgröße. Bitte ein größeres Etikettenformat wählen."
                    }
                }
            }
        case .parcel:
            if parcel == nil { return "Bitte ein gekauftes DHL-Paketlabel auswählen." }
            if parcel?.status == .printing { return "Dieses Etikett wird gerade gedruckt." }
        case .postage:
            if journey.step == .postageSource { return available.isEmpty ? "Bitte zuerst ein Briefmarken-PDF importieren." : nil }
            if selected.isEmpty { return "Bitte mindestens eine verfügbare Briefmarke auswählen." }
            if journey.step == .format || journey.step == .review {
                if layout.capacity == 0 { return "Bitte ein größeres Etikettenformat wählen." }
            }
        case nil: break
        }
        return nil
    }

    private var validationCorrection: GuidedShippingJourney.Step? {
        let correction: GuidedShippingJourney.Step
        switch journey.task {
        case .letter:
            if !appStore.recipientAddress.isComplete { correction = .recipient }
            else if !appStore.senderAddress.isComplete { return nil }
            else if appStore.letterWithPostage && letterStamp == nil { correction = .franking }
            else { correction = .format }
        case .postage:
            correction = selected.isEmpty ? .postageSelection : .format
        default: return nil
        }
        guard let index = journey.task?.steps.firstIndex(of: correction), index < journey.index else { return nil }
        return correction
    }

    private func openPreview() {
        switch journey.task {
        case .letter:
            appStore.selectedShipmentKind = .letter
            appStore.createManualAddressLabel()
        case .parcel:
            if let parcel { appStore.presentPrintPreview(parcel) }
        case .postage:
            appStore.preparePostageSheets(format: postageFormat, cutGuides: cutGuides)
        case nil: break
        }
    }
}
