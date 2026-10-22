import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appStore: AppStore

    var body: some View {
        Form {
            Section("RW403B") {
                Stepper("Geschwindigkeit: \(appStore.speed)", value: $appStore.speed, in: 1...8)
                Stepper("Druckdichte: \(appStore.density)", value: $appStore.density, in: 1...15)
            }
            Section("Etikettenformat") {
                LabelFormatControls(appStore: appStore, showHeading: false)
            }
            Section("Absender für Etsy-Briefetiketten") {
                TextField("Name oder Firma", text: $appStore.senderName)
                TextField("Straße und Hausnummer", text: $appStore.senderStreet)
                HStack {
                    TextField("PLZ", text: $appStore.senderPostalCode)
                        .frame(width: 80)
                    TextField("Ort", text: $appStore.senderCity)
                }
                TextField("Land", text: $appStore.senderCountry)
            }
        }
    }
}
