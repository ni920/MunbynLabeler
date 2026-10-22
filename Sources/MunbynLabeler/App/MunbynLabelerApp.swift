import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct MunbynLabelerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appStore = AppStore()

    var body: some Scene {
        WindowGroup("Munbyn Labeler", id: "main") {
            ContentView()
                .environmentObject(appStore)
                .frame(minWidth: 920, minHeight: 620)
                .onOpenURL { url in
                    appStore.handleIncomingURL(url)
                }
        }
        .defaultSize(width: 1_080, height: 720)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Etikett importieren …") {
                    appStore.showImporter = true
                }
                .keyboardShortcut("o")

                Button("Bluetooth-Suche starten") {
                    appStore.bluetooth.startScanning()
                }
                .keyboardShortcut("r")

                Button("Etsy-Adresse aus CSV übernehmen …") {
                    appStore.showEtsyImporter = true
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appStore)
        }
    }
}
