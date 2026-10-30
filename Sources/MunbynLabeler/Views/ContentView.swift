import LabelCore
import SwiftUI
import UniformTypeIdentifiers

private enum SidebarSelection: String, CaseIterable, Identifiable {
    case printer
    case letters
    case queue
    case postage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .printer: "Versenden"
        case .letters: "Briefverlauf"
        case .queue: "Druckaufträge"
        case .postage: "Briefmarken"
        }
    }

    var icon: String {
        switch self {
        case .printer: "printer.fill"
        case .letters: "envelope"
        case .queue: "list.bullet.rectangle"
        case .postage: "rectangle.stack"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var journey = GuidedShippingJourney()
    @State private var selection: SidebarSelection? = .printer

    var body: some View {
        NavigationSplitView {
            List(SidebarSelection.allCases, selection: $selection) { item in
                Label(item.title, systemImage: item.icon)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .navigationTitle("Label Helper")
            .navigationSplitViewColumnWidth(min: 190, ideal: 200, max: 260)
        } detail: {
            switch selection ?? .printer {
            case .printer:
                if appStore.guidedMode {
                    GuidedShippingView(appStore: appStore, postage: appStore.postage, jobs: appStore.jobs,
                                       controller: appStore.letterFlowController, journey: $journey)
                } else {
                    DashboardView(appStore: appStore, bluetooth: appStore.bluetooth, jobStore: appStore.jobs)
                }
            case .letters:
                LetterFlowHistoryView(appStore: appStore, store: appStore.letterFlows)
            case .queue:
                QueueView(appStore: appStore, jobStore: appStore.jobs)
            case .postage:
                PostageBundleView(appStore: appStore, store: appStore.postage)
            }
        }
        .fileImporter(
            isPresented: $appStore.showImporter,
            allowedContentTypes: [.pdf, .png, .jpeg],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls): appStore.importFiles(urls, presentPreview: !appStore.guidedMode)
            case .failure(let error): appStore.lastMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $appStore.showPostageImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { appStore.importPostageBundle(url) }
            case .failure(let error): appStore.lastMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $appStore.showEtsyImporter,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { appStore.loadEtsyCSV(url) }
            case .failure(let error): appStore.lastMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $appStore.showEtsyImportReview) {
            EtsyImportView(appStore: appStore)
        }
        .sheet(isPresented: $appStore.showBrowserOrderReview) {
            BrowserOrderReviewView(appStore: appStore)
        }
        .sheet(item: $appStore.previewJob) { job in
            PrintPreviewView(appStore: appStore, job: job)
        }
        .sheet(item: $appStore.postagePreview) { batch in
            PostagePrintPreviewView(appStore: appStore, bluetooth: appStore.bluetooth, batch: batch)
        }
        .sheet(item: $appStore.letterFlowPreview) { flow in
            LetterFlowView(appStore: appStore, store: appStore.letterFlows, controller: appStore.letterFlowController,
                           bluetooth: appStore.bluetooth, initialFlow: flow)
        }
        .alert("Etsy-Import fehlgeschlagen", isPresented: $appStore.showEtsyImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appStore.lastMessage ?? "Die CSV-Datei konnte nicht importiert werden.")
        }
        .onChange(of: appStore.shippingImportSequence) { _, _ in
            selection = .printer
            journey.choose(appStore.selectedShipmentKind == .letter ? .letter : .parcel)
        }
        .onChange(of: appStore.labelImportSequence) { _, _ in
            guard let id = appStore.lastImportedLabelJobID else { return }
            selection = .printer
            journey.receiveParcel(id)
        }
        .onChange(of: appStore.postageImportSequence) { _, _ in
            guard appStore.postageImportSucceeded else { return }
            if appStore.guidedMode, selection == .printer {
                journey.receivePostage()
            } else { selection = .postage }
        }
        .onChange(of: appStore.homeRequestSequence) { _, _ in
            selection = .printer
            journey.reset()
            appStore.lastMessage = nil
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if selection == .printer {
                    Picker("Bedienmodus", selection: $appStore.guidedMode) {
                        Text("Geführt").tag(true)
                        Text("Direkt").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .help("Geführt: Schritt für Schritt. Direkt: alle Versandfelder zusammen.")
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Menu("Importieren") {
                    Button("PDF oder Bild …", action: appStore.requestLabelImport)
                    Button("Etsy-Adresse aus CSV …") { appStore.showEtsyImporter = true }
                    Button("Briefmarken-Bündel …") { appStore.showPostageImporter = true }
                }
                .accessibilityLabel("Importieren")
                .help("Etikett, Briefmarken oder Etsy-Adressen importieren")
                PrinterConnectionView(appStore: appStore, bluetooth: appStore.bluetooth, handlesMenuRequests: true)
            }
        }
    }
}
