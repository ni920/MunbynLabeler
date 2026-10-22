import LabelCore
import SwiftUI

struct BrowserOrderReviewView: View {
    @ObservedObject var appStore: AppStore
    @State private var shipmentKind: ShipmentKind = .letter

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "cart.badge.checkmark")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Etsy-Bestellung empfangen")
                        .font(.title2.weight(.semibold))
                    if let order {
                        Text("Bestellung #\(order.orderID)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let order {
                GroupBox("Empfänger") {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(order.recipient.lines, id: \.self) { line in
                            Text(line)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                if !order.items.isEmpty {
                    GroupBox("Artikel") {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(order.items.prefix(8)) { item in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(item.title)
                                        .lineLimit(2)
                                    Spacer()
                                    Text("× \(item.quantity)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Was möchtest du versenden?")
                        .font(.headline)
                    Picker("Versandart", selection: $shipmentKind) {
                        ForEach(ShipmentKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.icon).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                if shipmentKind == .letter && !appStore.senderAddress.isComplete {
                    HStack {
                        Label("Bitte den Absender einmal in den Einstellungen hinterlegen.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Spacer()
                        SettingsLink {
                            Text("Einstellungen")
                        }
                    }
                    .font(.callout)
                }
            } else {
                ContentUnavailableView("Keine Bestellung", systemImage: "cart")
            }

            HStack {
                Button("Abbrechen", role: .cancel) {
                    appStore.dismissIncomingBrowserOrder()
                }
                Spacer()
                Button(shipmentKind == .letter ? "Brief vorbereiten" : "Paket vorbereiten") {
                    appStore.acceptIncomingBrowserOrder(as: shipmentKind)
                }
                .buttonStyle(.borderedProminent)
                .disabled(order == nil)
            }
        }
        .padding(24)
        .frame(width: 570)
    }

    private var order: BrowserOrderPayload? {
        appStore.incomingBrowserOrder
    }
}
