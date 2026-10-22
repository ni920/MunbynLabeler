import SwiftUI
import UniformTypeIdentifiers

private enum SidebarSelection: String, CaseIterable, Identifiable {
    case printer
    case queue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .printer: "Drucken"
        case .queue: "Warteschlange"
        }
    }

    var icon: String {
        switch self {
        case .printer: "printer.fill"
        case .queue: "list.bullet.rectangle"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var selection: SidebarSelection? = .printer

    var body: some View {
        NavigationSplitView {
            List(SidebarSelection.allCases, selection: $selection) { item in
                Label(item.title, systemImage: item.icon)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .navigationTitle("Munbyn Labeler")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            switch selection ?? .printer {
            case .printer:
                DashboardView(appStore: appStore, bluetooth: appStore.bluetooth, jobStore: appStore.jobs)
            case .queue:
                QueueView(appStore: appStore, jobStore: appStore.jobs)
            }
        }
        .fileImporter(
            isPresented: $appStore.showImporter,
            allowedContentTypes: [.pdf, .png, .jpeg],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls): appStore.importFiles(urls)
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
        .alert("Etsy-Import fehlgeschlagen", isPresented: $appStore.showEtsyImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appStore.lastMessage ?? "Die CSV-Datei konnte nicht importiert werden.")
        }
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    Button("PDF oder Bild …") {
                        appStore.showImporter = true
                    }
                    Button("Etsy-Adresse aus CSV …") {
                        appStore.showEtsyImporter = true
                    }
                } label: {
                    Label("Importieren", systemImage: "plus")
                }

                Button {
                    appStore.bluetooth.startScanning()
                } label: {
                    Label("Bluetooth suchen", systemImage: "wave.3.right")
                }

                SettingsLink {
                    Label("Einstellungen", systemImage: "gearshape")
                }
            }
        }
    }
}
