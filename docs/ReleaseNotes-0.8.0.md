# Label Helper v0.8.0

Der Briefmarkenbestand lässt sich jetzt verwalten. Fehlgedruckte Marken können erneut verwendet werden.

- Die Markenliste lässt sich nach **Verfügbar**, **Genutzt** und **Alle** filtern, jeweils mit Anzahl.
- Genutzte Marken zeigen das Druckdatum. Bei mehrfach gedruckten Marken steht die Anzahl dabei, bei Briefen auch der Empfänger.
- **Erneut verwenden …** gibt eine gedruckte Marke nach einem Fehldruck und einer Bestätigung wieder frei. Die Marke wird gleich für den nächsten Druck ausgewählt. Der bisherige Druckverlauf bleibt erhalten.
- Marken eines noch nicht abgeschlossenen Briefversands werden weiterhin über **Im Briefversand prüfen** geklärt.
- Eine verfügbare Marke kann per Rechtsklick **als genutzt markiert** werden, zum Beispiel wenn sie außerhalb der App gedruckt wurde.
- Ein vorhandener Briefmarkenbestand lädt weiterhin. Marken, die vor diesem Update gedruckt wurden, haben kein Druckdatum.

## Installation

`LabelHelper-universal.zip` herunterladen, entpacken und **Label Helper.app** in **Programme** verschieben. Die App enthält Intel- und Apple-Silicon-Code und benötigt macOS 14 oder neuer. Bestehende Installationen erhalten das Update über den integrierten Sparkle-Updater.

Die App ist derzeit ad hoc signiert und nicht von Apple notarisiert. macOS kann beim ersten Öffnen eine Freigabe unter **Systemeinstellungen → Datenschutz & Sicherheit → Dennoch öffnen** verlangen. Ohne feste Apple-Signieridentität kann macOS nach dem Update erneut um Bluetooth-Zugriff bitten.

## Prüfung

Universal-Build, Core-Regressionstests und Browser-Erweiterung werden im GitHub-Release-Workflow geprüft. Die neuen Bestandsfunktionen sind durch Regressionstests abgedeckt. Dazu gehören erneute Verwendung, Druckzähler, gespeicherter Verlauf und das Laden älterer Bestände. Gekaufte Marken wurden zur Release-Prüfung nicht physisch gedruckt.
