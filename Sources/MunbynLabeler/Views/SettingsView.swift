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
                LabeledContent("Größe", value: "100 × 150 mm")
                LabeledContent("Auflösung", value: "203 dpi / 800 × 1200 Punkte")
            }
        }
    }
}
