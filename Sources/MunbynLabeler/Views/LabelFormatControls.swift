import LabelCore
import SwiftUI

struct LabelFormatControls: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject private var bluetooth: BluetoothPrinterService
    var showHeading: Bool

    init(appStore: AppStore, showHeading: Bool = true) {
        self.appStore = appStore
        self.bluetooth = appStore.bluetooth
        self.showHeading = showHeading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showHeading {
                Text("Etikettenmaterial")
                    .font(.headline)
            }

            LabelMaterialPicker(appStore: appStore)

            if appStore.labelStockMode == .continuous100 {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Brief: 100 × 55 mm + 2 mm Schnittzugabe", systemImage: "envelope")
                    Label("Paket: 100 × 150 mm + 2 mm Schnittzugabe", systemImage: "shippingbox")
                    if bluetooth.supportsContinuousStock {
                        Label("Bluetooth mit Firmware \(bluetooth.firmwareVersion ?? "1.1.49")", systemImage: "wave.3.right")
                            .font(.callout)
                    } else {
                        Label("Bluetooth benötigt Firmware ab 1.1.49 und eine Druckerverbindung. Alternativ über USB mit Medientyp Endlos/Continuous drucken.", systemImage: "info.circle")
                            .font(.callout).fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Unter jedem Endlosetikett wird eine gestrichelte Schnittlinie auf 2 mm zusätzlichem Rand gedruckt. Beide Größen verwenden dieselbe Rolle.")
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

            DisclosureGroup("Technische Angaben") {
                Text("\(appStore.printedLabelFormat(appStore.selectedLetterLabelFormat).technicalDescription) · 203 dpi")
                    .font(.callout).textSelection(.enabled)
            }
        }
    }
}

struct LabelMaterialPicker: View {
    @ObservedObject var appStore: AppStore

    var body: some View {
        Picker("Material", selection: $appStore.labelStockMode) {
            ForEach(AppStore.LabelStockMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }.frame(maxWidth: 320)
    }
}

struct PostageFormatControls: View {
    @ObservedObject var appStore: AppStore
    @Binding var formatID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabelMaterialPicker(appStore: appStore)
            Picker("Etikettenformat", selection: Binding(
                get: { appStore.postageFormat(for: formatID).id },
                set: { formatID = $0 }
            )) {
                ForEach(appStore.postageFormats) { Text($0.name).tag($0.id) }
            }.frame(maxWidth: 340)
        }
    }
}

/// Preparing a stamp preview works offline. Paid stamps require the confirmed
/// Bluetooth print path, so an unknown/old firmware never falls back to USB.
struct PostageMaterialRequirement: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject var bluetooth: BluetoothPrinterService

    var body: some View {
        if appStore.labelStockMode == .continuous100 && !bluetooth.supportsContinuousStock {
            Label("Zum Drucken von Briefmarken auf Endlosrolle den RW403B mit Firmware ab 1.1.49 über Bluetooth verbinden. Die Vorschau kannst du bereits vorbereiten.", systemImage: "info.circle")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }
}
