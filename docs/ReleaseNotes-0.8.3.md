# Label Helper v0.8.3

Die Briefmarken-Seite ist übersichtlicher und stärker an native macOS-Bedienmuster angelehnt.

- Das Menü **Auswahl** in der Fenster-Toolbar bündelt Auswählen, Kopieren, Als-genutzt-Markieren und Löschen.
- Jede Marke hat ein einheitliches **…**-Menü für ihre Aktionen. Die gleichen Befehle bleiben per Rechtsklick erreichbar.
- Zusätzliche Kopier-Buttons und der doppelte Import-Button entfallen im gefüllten Bestand. Bei leerem Bestand führt eine klare Import-Aktion zum PDF-Bündel.
- Drucklayout, Bestandsfilter und Druckvorschau sind klarer angeordnet. Schutz vor versehentlichem Löschen und die Bestätigungen zur erneuten Verwendung bleiben erhalten.

## Installation

`LabelHelper-universal.zip` herunterladen, entpacken und **Label Helper.app** in **Programme** verschieben. Die App enthält Intel- und Apple-Silicon-Code und benötigt macOS 14 oder neuer. Bestehende Installationen erhalten das Update über den integrierten Sparkle-Updater.

Die App ist derzeit ad hoc signiert und nicht von Apple notarisiert. macOS kann beim ersten Öffnen eine Freigabe unter **Systemeinstellungen → Datenschutz & Sicherheit → Dennoch öffnen** verlangen. Ohne feste Apple-Signieridentität kann macOS nach dem Update erneut um Bluetooth-Zugriff bitten.

## Prüfung

Universal-Build, Core-Regressionstests und Browser-Erweiterung werden im GitHub-Release-Workflow geprüft.
