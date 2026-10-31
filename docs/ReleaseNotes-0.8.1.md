# Label Helper v0.8.1

Fehlerbehebung für den Briefmarken-Tab.

- Bei Endlosrolle ohne verbundenen Drucker mit Firmware ab 1.1.49 blieb das Fenster im Tab **Briefmarken** komplett leer. Der Hinweis zur Bluetooth-Verbindung erzwang eine viel zu große Fensterhöhe. Der Tab zeigt jetzt wieder Bestand und Hinweis an. Der Fehler bestand schon vor 0.8.0.

## Installation

`LabelHelper-universal.zip` herunterladen, entpacken und **Label Helper.app** in **Programme** verschieben. Die App enthält Intel- und Apple-Silicon-Code und benötigt macOS 14 oder neuer. Bestehende Installationen erhalten das Update über den integrierten Sparkle-Updater.

Die App ist derzeit ad hoc signiert und nicht von Apple notarisiert. macOS kann beim ersten Öffnen eine Freigabe unter **Systemeinstellungen → Datenschutz & Sicherheit → Dennoch öffnen** verlangen. Ohne feste Apple-Signieridentität kann macOS nach dem Update erneut um Bluetooth-Zugriff bitten.

## Prüfung

Universal-Build, Core-Regressionstests und Browser-Erweiterung werden im GitHub-Release-Workflow geprüft. Die Layoutkorrektur wurde offscreen mit Endlosrolle und Stanzetiketten für Briefmarken, geführten Versand, Übersicht, Briefverlauf und Warteschlange geprüft.
