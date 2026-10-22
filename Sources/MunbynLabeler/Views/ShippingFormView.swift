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
            .onChange(of: appStore.selectedShipmentKind) { _, kind in
                if kind == .parcel {
                    appStore.selectedFormatID = LabelFormat.shipping100x150.id
                }
            }

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
                    Label("Absender", systemImage: "person.text.rectangle")
                        .font(.headline)
                    senderGrid
                }
                .padding(8)
            }

            GroupBox {
                LabelFormatControls(appStore: appStore, showHeading: false)
                    .padding(8)
            } label: {
                Label("Etikettenformat", systemImage: "rectangle.and.pencil.and.ellipsis")
            }

            HStack {
                if !appStore.recipientAddress.isComplete || !appStore.senderAddress.isComplete {
                    Label("Empfänger und Absender vollständig ausfüllen", systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Adressetikett erstellen") {
                    appStore.createManualAddressLabel()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!appStore.recipientAddress.isComplete || !appStore.senderAddress.isComplete)
            }
        }
    }

    private var parcelForm: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 42)

                VStack(alignment: .leading, spacing: 8) {
                    Text("DHL-Paketlabel drucken")
                        .font(.headline)
                    Text("Kaufe das Versandlabel bei DHL und lade anschließend die PDF herunter. Die Empfängeradresse ist bereits im DHL-Label enthalten; eine Etsy-CSV wird dafür nicht benötigt.")
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

    private var senderGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 9) {
            GridRow {
                Text("Name")
                    .frame(width: 86, alignment: .leading)
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
                        .frame(width: 100)
                    TextField("Ort", text: $appStore.senderCity)
                }
            }
            GridRow {
                Text("Land")
                TextField("Land", text: $appStore.senderCountry)
            }
        }
        .textFieldStyle(.roundedBorder)
    }
}
