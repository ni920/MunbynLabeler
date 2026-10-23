import LabelCore
import SwiftUI

struct ShippingFormView: View {
    @ObservedObject var appStore: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Versand vorbereiten")
                    .font(.title2.weight(.semibold))
                Text("Wähle zuerst, was du verschicken möchtest.")
                    .foregroundStyle(.secondary)
            }

            Picker("Versandart", selection: $appStore.selectedShipmentKind) {
                ForEach(ShipmentKind.allCases) { kind in
                    Label(kind.title, systemImage: kind.icon).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Divider()

            switch appStore.selectedShipmentKind {
            case .letter:
                letterForm
            case .parcel:
                parcelForm
            }
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var letterForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            browserOrderSummary

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Empfänger", systemImage: "person.crop.rectangle")
                            .font(.headline)
                        Spacer()
                        Button("Aus Etsy-CSV übernehmen …") {
                            appStore.showEtsyImporter = true
                        }
                    }
                    addressGrid(
                        name: $appStore.recipientName,
                        street1: $appStore.recipientStreet1,
                        street2: $appStore.recipientStreet2,
                        postalCode: $appStore.recipientPostalCode,
                        city: $appStore.recipientCity,
                        country: $appStore.recipientCountry
                    )
                }
                .padding(8)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Absender aus den Einstellungen", systemImage: "person.text.rectangle")
                            .font(.headline)
                        Spacer()
                        SettingsLink {
                            Text(appStore.senderAddress.isComplete ? "Ändern" : "Einrichten")
                        }
                    }
                    if appStore.senderAddress.isComplete {
                        Text(appStore.senderAddress.singleLine)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    } else {
                        Label("Bitte den Absender einmal hinterlegen.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
                .padding(8)
            }

            GroupBox {
                LabelFormatControls(appStore: appStore, showHeading: false)
                    .padding(8)
            } label: {
                Label("Etikettenmaterial", systemImage: "rectangle.and.pencil.and.ellipsis")
            }

            Text(appStore.labelStockMode == .continuous100
                ? "Mit der Endlosrolle nutzt die App automatisch 55 mm Länge für Briefe und 150 mm für Pakete. Du musst die Rolle nicht wechseln."
                : "89 × 36 mm ist eine kompakte Briefgröße. Die App merkt sich dein zuletzt gewähltes Briefformat; Paketlabel bleiben bei 100 × 150 mm.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                if !appStore.recipientAddress.isComplete || !appStore.senderAddress.isComplete {
                    Label("Empfänger und Absender vollständig ausfüllen", systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Druckvorschau erstellen") {
                    appStore.createManualAddressLabel()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!appStore.recipientAddress.isComplete || !appStore.senderAddress.isComplete)
            }
        }
    }

    private var parcelForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            browserOrderSummary

            GroupBox {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 42)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("DHL-Paketlabel drucken")
                            .font(.headline)
                        Text("Kaufe das Versandlabel bei DHL und lade anschließend die PDF herunter. Die Empfängeradresse ist bereits im DHL-Label enthalten.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Label("Format: Versand 100 × 150 mm", systemImage: "rectangle.portrait")
                            .font(.callout)
                        Button("DHL-PDF auswählen …") {
                            appStore.chooseDHLLabelImport()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 4)
                    }
                    Spacer()
                }
                .padding(12)
            }
        }
    }

    @ViewBuilder
    private var browserOrderSummary: some View {
        if let order = appStore.activeBrowserOrder {
            GroupBox {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "cart.badge.checkmark")
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Etsy-Bestellung #\(order.orderID)")
                            .font(.headline)
                        Text(order.recipient.singleLine)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(8)
            }
        }
    }

    private func addressGrid(
        name: Binding<String>,
        street1: Binding<String>,
        street2: Binding<String>,
        postalCode: Binding<String>,
        city: Binding<String>,
        country: Binding<String>
    ) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 9) {
            GridRow {
                Text("Name")
                    .frame(width: 86, alignment: .leading)
                TextField("Vor- und Nachname oder Firma", text: name)
            }
            GridRow {
                Text("Straße")
                TextField("Straße und Hausnummer", text: street1)
            }
            GridRow {
                Text("Zusatz")
                TextField("Optional: Wohnung, Etage oder Firma", text: street2)
            }
            GridRow {
                Text("Ort")
                HStack {
                    TextField("PLZ", text: postalCode)
                        .frame(width: 100)
                    TextField("Ort", text: city)
                }
            }
            GridRow {
                Text("Land")
                TextField("Land", text: country)
            }
        }
        .textFieldStyle(.roundedBorder)
    }

}
