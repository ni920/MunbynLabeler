import LabelCore
import SwiftUI

struct EtsyImportView: View {
    @ObservedObject var appStore: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOrderID: String?

    init(appStore: AppStore) {
        self.appStore = appStore
        _selectedOrderID = State(initialValue: appStore.pendingEtsyOrders.first?.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Adresse aus Etsy übernehmen")
                    .font(.title2.weight(.semibold))
                Text("Wähle eine Bestellung. Die Lieferadresse wird ins Brief-Formular eingetragen.")
                    .foregroundStyle(.secondary)
            }

            List(appStore.pendingEtsyOrders, selection: $selectedOrderID) { order in
                VStack(alignment: .leading, spacing: 3) {
                    Text(order.recipientName)
                        .fontWeight(.medium)
                    Text("#\(order.id) · \(order.street1), \(order.postalCode) \(order.city)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(order.id)
                .padding(.vertical, 4)
            }
            .frame(minHeight: 260)

            HStack {
                Button("Abbrechen") {
                    appStore.showEtsyImportReview = false
                    dismiss()
                }
                Spacer()
                Button("Adresse übernehmen") {
                    guard let selectedOrderID,
                          let order = appStore.pendingEtsyOrders.first(where: { $0.id == selectedOrderID }) else {
                        return
                    }
                    appStore.applyEtsyOrder(order)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedOrderID == nil)
            }
        }
        .padding(24)
        .frame(width: 640, height: 460)
    }
}
