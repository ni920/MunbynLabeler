import LabelCore
import SwiftUI

private enum EtsyImportPurpose: String, CaseIterable, Identifiable {
    case address
    case dhl

    var id: String { rawValue }

    var title: String {
        switch self {
        case .address: "Brief / Adressetikett"
        case .dhl: "DHL-Paketlabel"
        }
    }
}

struct EtsyImportView: View {
    @ObservedObject var appStore: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var purpose: EtsyImportPurpose = .address
    @State private var selectedOrderIDs: Set<String>

    init(appStore: AppStore) {
        self.appStore = appStore
        _selectedOrderIDs = State(initialValue: Set(appStore.pendingEtsyOrders.map(\.id)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Etsy-Bestellungen importieren")
                    .font(.title2.weight(.semibold))
                Text("\(appStore.pendingEtsyOrders.count) Versandadressen wurden in der CSV gefunden.")
                    .foregroundStyle(.secondary)
            }

            Picker("Was möchtest du versenden?", selection: $purpose) {
                ForEach(EtsyImportPurpose.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if purpose == .address {
                addressImportContent
            } else {
                dhlImportContent
            }

            HStack {
                Button("Abbrechen") {
                    appStore.showEtsyImportReview = false
                    dismiss()
                }
                Spacer()
                if purpose == .address {
                    Button("\(selectedOrderIDs.count) Etikett\(selectedOrderIDs.count == 1 ? "" : "en") erstellen") {
                        appStore.createEtsyAddressLabels(orderIDs: selectedOrderIDs)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedOrderIDs.isEmpty || !appStore.senderAddress.isComplete)
                } else {
                    Button("DHL-PDF auswählen …") {
                        appStore.chooseDHLLabelImport()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(width: 720, height: 680)
    }

    private var addressImportContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Bestellungen") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button("Alle auswählen") {
                            selectedOrderIDs = Set(appStore.pendingEtsyOrders.map(\.id))
                        }
                        Button("Keine") {
                            selectedOrderIDs.removeAll()
                        }
                        Spacer()
                        Text("\(selectedOrderIDs.count) ausgewählt")
                            .foregroundStyle(.secondary)
                    }

                    List(appStore.pendingEtsyOrders) { order in
                        Toggle(isOn: selectionBinding(for: order.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(order.recipientName)
                                    .fontWeight(.medium)
                                Text("#\(order.id) · \(order.street1), \(order.postalCode) \(order.city)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                    .frame(height: 170)
                }
                .padding(8)
            }

            GroupBox("Absender") {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("Name")
                        TextField("Vor- und Nachname oder Firma", text: $appStore.senderName)
                    }
                    GridRow {
                        Text("Straße")
                        TextField("Straße und Hausnummer", text: $appStore.senderStreet)
                    }
                    GridRow {
                        Text("Ort")
                        HStack {
                            TextField("PLZ", text: $appStore.senderPostalCode)
                                .frame(width: 90)
                            TextField("Ort", text: $appStore.senderCity)
                        }
                    }
                    GridRow {
                        Text("Land")
                        TextField("Land", text: $appStore.senderCountry)
                    }
                }
                .padding(8)
            }

            GroupBox {
                LabelFormatControls(appStore: appStore, showHeading: false)
                    .padding(8)
            }

            if !appStore.senderAddress.isComplete {
                Label("Für Briefetiketten wird ein vollständiger Absender benötigt.", systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var dhlImportContent: some View {
        ContentUnavailableView {
            Label("DHL-Label als PDF importieren", systemImage: "shippingbox")
        } description: {
            Text("Die Etsy-CSV enthält die Lieferadresse, aber keine bezahlte DHL-Frankierung. Kaufe das Versandlabel bei DHL und wähle anschließend die heruntergeladene PDF aus. Sie wird im aktuell gewählten Etikettenformat gedruckt.")
        }
        .frame(maxHeight: .infinity)
    }

    private func selectionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { selectedOrderIDs.contains(id) },
            set: { selected in
                if selected { selectedOrderIDs.insert(id) }
                else { selectedOrderIDs.remove(id) }
            }
        )
    }
}
