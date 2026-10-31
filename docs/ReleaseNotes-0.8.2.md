# Label Helper v0.8.2

Ausgewählte Briefmarken lassen sich jetzt gemeinsam verwalten.

- Das kompakte Menü **Auswahl** kopiert Sendungsnummern, markiert ausgewählte Marken als genutzt oder löscht sie aus dem Bestand.
- Das Löschen ist als destruktive Aktion gekennzeichnet und muss bestätigt werden. Reservierte, laufende oder bereits genutzte Marken werden dabei nicht entfernt.
- Dieselben Aktionen stehen für einzelne verfügbare Marken per Rechtsklick bereit.
- Gelöschte Marken lassen sich durch einen erneuten Import des ursprünglichen PDF-Bündels wieder hinzufügen.

## Installation

`LabelHelper-universal.zip` herunterladen, entpacken und **Label Helper.app** in **Programme** verschieben. Die App enthält Intel- und Apple-Silicon-Code und benötigt macOS 14 oder neuer. Bestehende Installationen erhalten das Update über den integrierten Sparkle-Updater.

Die App ist derzeit ad hoc signiert und nicht von Apple notarisiert. macOS kann beim ersten Öffnen eine Freigabe unter **Systemeinstellungen → Datenschutz & Sicherheit → Dennoch öffnen** verlangen. Ohne feste Apple-Signieridentität kann macOS nach dem Update erneut um Bluetooth-Zugriff bitten.

## Prüfung

Universal-Build, Core-Regressionstests und Browser-Erweiterung werden im GitHub-Release-Workflow geprüft. Die Bestandslöschung ist durch Regressionstests für Statusschutz und dauerhafte Speicherung abgedeckt.
