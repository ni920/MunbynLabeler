import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appStore: AppStore

    var body: some View {
        TabView {
            GeneralSettingsView(appStore: appStore)
                .tabItem {
                    Label("Allgemein", systemImage: "slider.horizontal.3")
                }

            BluetoothDiagnosticsView(bluetooth: appStore.bluetooth)
                .tabItem {
                    Label("Bluetooth", systemImage: "wave.3.right.circle")
                }
        }
        .frame(width: 620, height: 520)
        .scenePadding()
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var appStore: AppStore

    var body: some View {
        Form {
            Section("RW403B") {
                Stepper("Geschwindigkeit: \(appStore.speed)", value: $appStore.speed, in: 1...8)
                Stepper("Druckdichte: \(appStore.density)", value: $appStore.density, in: 1...15)
            }

            Section("Standard-Etikettenformat") {
                LabelFormatControls(appStore: appStore, showHeading: false)
            }

            Section("Absender für Briefetiketten") {
                TextField("Name oder Firma", text: $appStore.senderName)
                TextField("Straße und Hausnummer", text: $appStore.senderStreet)
                HStack {
                    TextField("PLZ", text: $appStore.senderPostalCode)
                        .frame(width: 90)
                    TextField("Ort", text: $appStore.senderCity)
                }
                TextField("Land", text: $appStore.senderCountry)
            }
        }
        .formStyle(.grouped)
    }
}
