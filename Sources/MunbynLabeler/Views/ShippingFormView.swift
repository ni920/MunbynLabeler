import LabelCore
import SwiftUI

struct ShippingFormView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject var postage: PostageStampStore
    @ObservedObject var controller: LetterFlowController

    private var availableStamps: [PostageStamp] { postage.entries.filter { $0.status == .available }.map(\.stamp) }
    private var busy: Bool { appStore.printInProgress || appStore.printingPostageBatch || controller.activeFlowID != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker("Versandart", selection: $appStore.selectedShipmentKind) {
                ForEach(ShipmentKind.allCases) { kind in
                    Label(kind.title, systemImage: kind.icon).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)

            Divider()

            switch appStore.selectedShipmentKind {
            case .letter:
                letterForm
            case .parcel:
                parcelForm
            }
        }

    }

    private var letterForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            browserOrderSummary

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Empfänger")
                            .font(.headline)
                        Spacer()
                        Button("Aus Etsy-CSV übernehmen …") {
                            appStore.showEtsyImporter = true
                        }
                    }
                    RecipientEditorView(appStore: appStore)
                }
                .padding(8)
            }

            GroupBox {
                SenderSummaryView(appStore: appStore).padding(12)
            }

            GroupBox {
                LabelFormatControls(appStore: appStore, showHeading: false)
                    .padding(8)
            } label: {
                Text("Etikettenformat")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Adresse + Briefmarke", isOn: $appStore.letterWithPostage)
                    if appStore.letterWithPostage {
                        Text("Zwei Etiketten in einem Ablauf: zuerst die Adresse, dann eine Briefmarke. Danach steht die Sendungsnummer zum Kopieren bereit.")
                            .font(.callout).foregroundStyle(.secondary)
                        Picker("Briefmarke", selection: $appStore.selectedLetterPostageID) {
                            Text("Briefmarke auswählen …").tag("")
                            ForEach(availableStamps) { stamp in
                                Text("\(stamp.amount) € · …\(stamp.id.suffix(8))").tag(stamp.id)
                            }
                        }
                        Text("Beide Etiketten: \(appStore.selectedLetterLabelFormat.sizeDescription). Bitte die für deinen Brief passende Frankierung auswählen.")
                            .font(.caption).foregroundStyle(.secondary)
                        if availableStamps.isEmpty {
                            Button("Briefmarken-PDF importieren …") { appStore.showPostageImporter = true }
                        }
                        PostageMaterialRequirement(appStore: appStore, bluetooth: appStore.bluetooth)
                    }
                }.padding(8)
            } label: { Text("Frankierung") }
            .disabled(busy)

            HStack {
                if !appStore.recipientAddress.isComplete || !appStore.senderAddress.isComplete {
                    Label("Empfänger und Absender vollständig ausfüllen", systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(appStore.letterWithPostage ? "Briefablauf prüfen" : "Druckvorschau erstellen") {
                    appStore.createManualAddressLabel()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!appStore.recipientAddress.isComplete || !appStore.senderAddress.isComplete || busy ||
                    (appStore.letterWithPostage && !availableStamps.contains { $0.id == appStore.selectedLetterPostageID }))
            }
        }
        .onChange(of: availableStamps.map(\.id)) { _, ids in
            guard !appStore.selectedLetterPostageID.isEmpty, !ids.contains(appStore.selectedLetterPostageID) else { return }
            let oldAmount = postage.entries.first { $0.id == appStore.selectedLetterPostageID }?.stamp.amount
            appStore.selectedLetterPostageID = availableStamps.first { $0.amount == oldAmount }?.id ?? ""
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

}
