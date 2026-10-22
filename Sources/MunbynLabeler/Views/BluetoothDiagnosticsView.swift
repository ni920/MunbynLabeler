import SwiftUI

struct BluetoothDiagnosticsView: View {
    @ObservedObject var bluetooth: BluetoothPrinterService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            connectionStatus

            if !bluetooth.discoveredDevices.isEmpty && !bluetooth.connectionState.isReady {
                discoveredDevices
            }

            GroupBox("Diagnoseprotokoll") {
                ScrollView {
                    if bluetooth.diagnostics.isEmpty {
                        ContentUnavailableView(
                            "Noch keine Diagnose",
                            systemImage: "wave.3.right.circle",
                            description: Text("Starte eine Suche oder verbinde den Drucker. Die Einträge erscheinen dann hier.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
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
            }
            .frame(maxHeight: .infinity)

            HStack {
                Button("Suche starten", action: bluetooth.startScanning)
                    .buttonStyle(.borderedProminent)
                Button("Suche stoppen", action: bluetooth.stopScanning)
                    .disabled(bluetooth.connectionState != .scanning)
                if bluetooth.connectionState.isReady {
                    Button("Verbindung trennen", action: bluetooth.disconnect)
                }

                Spacer()
                Text("Einträge können markiert und kopiert werden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var connectionStatus: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: bluetooth.connectionState.isReady ? "checkmark.circle.fill" : "wave.3.right.circle")
                .font(.title2)
                .foregroundStyle(bluetooth.connectionState.isReady ? Color.green : Color.accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(bluetooth.connectionState.title)
                    .font(.headline)
                if let detail = bluetooth.connectionState.detail {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    private var discoveredDevices: some View {
        GroupBox("Gefundene Geräte") {
            VStack(spacing: 8) {
                ForEach(bluetooth.discoveredDevices.prefix(8)) { device in
                    HStack {
                        Image(systemName: "printer")
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name)
                            Text("Signal \(device.rssi) dBm")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Verbinden") {
                            bluetooth.connect(to: device.id)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
