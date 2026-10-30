import SwiftUI

struct RecipientEditorView: View {
    @ObservedObject var appStore: AppStore

    var body: some View {
        Form {
            TextField("Name", text: $appStore.recipientName, prompt: Text("Vor- und Nachname oder Firma"))
            TextField("Straße", text: $appStore.recipientStreet1, prompt: Text("Straße und Hausnummer"))
            TextField("Zusatz", text: $appStore.recipientStreet2, prompt: Text("Optional"))
            TextField("PLZ", text: $appStore.recipientPostalCode)
            TextField("Ort", text: $appStore.recipientCity)
            TextField("Land", text: $appStore.recipientCountry)
        }
        .textFieldStyle(.roundedBorder)
    }
}

struct SenderSummaryView: View {
    @ObservedObject var appStore: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Absender").font(.headline)
                Spacer()
                SettingsLink { Text(appStore.senderAddress.isComplete ? "Bearbeiten …" : "Absender einrichten …") }
            }
            if appStore.senderAddress.isComplete {
                Text(appStore.senderAddress.singleLine).textSelection(.enabled)
            } else {
                Label("Bitte den vollständigen Absender einmal in den Einstellungen hinterlegen.", systemImage: "info.circle")
            }
        }
    }
}

struct PrinterConnectionView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject var bluetooth: BluetoothPrinterService
    var handlesMenuRequests = false
    @State private var localPresentation = false
    private var presentation: Binding<Bool> {
        handlesMenuRequests ? $appStore.showPrinterConnection : $localPresentation
    }
    private var busy: Bool { appStore.printInProgress || appStore.printingPostageBatch || appStore.letterFlowController.activeFlowID != nil }
    var body: some View {
        Button { presentation.wrappedValue.toggle() } label: {
            Label(bluetooth.connectionState.isReady ? "Drucker verbunden" : "Drucker verbinden …", systemImage: bluetooth.connectionState.isReady ? "printer.fill" : "printer")
        }
        .help("Drucker auswählen und Verbindungsstatus prüfen")
        .popover(isPresented: presentation) {
            VStack(alignment: .leading, spacing: 16) {
                Text(bluetooth.connectionState.title).font(.headline)
                if let firmware = bluetooth.firmwareVersion { Text("Firmware \(firmware)").font(.callout) }
                if let detail = bluetooth.connectionState.detail { Text(detail).fixedSize(horizontal: false, vertical: true) }
                if bluetooth.connectionState.isReady {
                    Button("Testetikett drucken", action: appStore.printTestLabel).disabled(busy)
                    Button("Verbindung trennen", action: bluetooth.disconnect).disabled(busy)
                } else {
                    Button("Drucker suchen", action: bluetooth.startScanning)
                    if bluetooth.connectionState == .scanning { ProgressView().controlSize(.small) }
                    ForEach(bluetooth.discoveredDevices.prefix(8)) { device in
                        HStack {
                            Label(device.name, systemImage: "printer")
                            Spacer()
                            Button("Verbinden") { bluetooth.connect(to: device.id) }
                        }
                    }
                }
                SettingsLink { Text("Bluetooth-Diagnose in Einstellungen …") }
            }
            .padding(20).frame(width: 340)
        }
    }
}
