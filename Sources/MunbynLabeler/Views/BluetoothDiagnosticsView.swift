import SwiftUI

struct BluetoothDiagnosticsView: View {
    @ObservedObject var bluetooth: BluetoothPrinterService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Bluetooth-Diagnose")
                .font(.largeTitle.weight(.semibold))
            Text("Beim ersten RW403B-Verbindungsversuch werden Dienst- und Kanal-IDs protokolliert. Damit lässt sich der Transport an die konkrete Firmware anpassen.")
                .foregroundStyle(.secondary)

            GroupBox {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 7) {
                        ForEach(Array(bluetooth.diagnostics.enumerated()), id: \.offset) { _, entry in
                            Text(entry)
                                .font(.system(.callout, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                }
            }

            HStack {
                Button("Suche starten", action: bluetooth.startScanning)
                    .buttonStyle(.borderedProminent)
                Button("Suche stoppen", action: bluetooth.stopScanning)
            }
        }
        .padding(28)
        .navigationTitle("Bluetooth-Diagnose")
    }
}
