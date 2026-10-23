import LabelCore
import SwiftUI

struct LabelFormatControls: View {
    @ObservedObject var appStore: AppStore
    var showHeading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showHeading {
                Text("Etikettenmaterial")
                    .font(.headline)
            }

            Picker("Material", selection: $appStore.labelStockMode) {
                ForEach(AppStore.LabelStockMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 320)

            if appStore.labelStockMode == .continuous100 {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Brief: 100 × 55 mm", systemImage: "envelope")
                    Label("Paket: 100 × 150 mm", systemImage: "shippingbox")
                    Text("Beide Größen werden von derselben Rolle gedruckt. Das Etikett anschließend an der Abrisskante manuell trennen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Picker("Format", selection: $appStore.letterFormatID) {
                    ForEach(LabelFormat.letterPresets) { format in
                        Text(format.name).tag(format.id)
                    }
                    Divider()
                    Text("Eigenes Format …").tag("custom")
                }
                .labelsHidden()
                .frame(maxWidth: 320)

                if appStore.letterFormatID == "custom" {
                    HStack(spacing: 18) {
                        Stepper(
                            "Breite: \(Int(appStore.customWidthMM.rounded())) mm",
                            value: $appStore.customWidthMM,
                            in: 20...108,
                            step: 1
                        )
                        Stepper(
                            "Höhe: \(Int(appStore.customHeightMM.rounded())) mm",
                            value: $appStore.customHeightMM,
                            in: 15...300,
                            step: 1
                        )
                    }
                }
            }

            Text("\(appStore.selectedLetterLabelFormat.technicalDescription) · 203 dpi")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
