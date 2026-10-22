import LabelCore
import SwiftUI

struct LabelFormatControls: View {
    @ObservedObject var appStore: AppStore
    var showHeading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showHeading {
                Text("Etikettenformat")
                    .font(.headline)
            }

            Picker("Format", selection: $appStore.selectedFormatID) {
                ForEach(LabelFormat.presets) { format in
                    Text(format.name).tag(format.id)
                }
                Divider()
                Text("Eigenes Format …").tag("custom")
            }
            .labelsHidden()
            .frame(maxWidth: 320)

            if appStore.selectedFormatID == "custom" {
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

            Text("\(appStore.selectedLabelFormat.technicalDescription) · 203 dpi")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
