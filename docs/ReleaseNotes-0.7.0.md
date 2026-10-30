# Label Helper v0.7.0

Munbyn Labeler heißt jetzt **Label Helper**. Einstellungen, Briefmarkenbestand und Druckverlauf bleiben durch dieselbe App-Kennung erhalten.

- Geführter Versand für Brief, DHL-Paketlabel und Briefmarken; alternativ bleibt der Direktmodus verfügbar.
- Endlosrollen lassen sich auch für Adresse + Briefmarke und Briefmarken-Bündel wählen. Bluetooth benötigt eine vom RW403B gemeldete Firmware ab **1.1.49**.
- Jedes Endlosetikett erhält eine gestrichelte Schnittlinie auf **2 mm zusätzlichem Rand**. Adresse und Barcodes werden nicht verkleinert oder überdeckt. Die Linie erscheint auch in der Vorschau.
- Internetmarken-Bündel werden in Originalgröße platzsparend aufgeteilt. Der Briefablauf druckt erst die Adresse, dann die ausgewählte Marke und bietet die vollständige Sendungsnummer zum Kopieren an.
- Gespeicherte Druckschritte und Markenreservierungen verhindern automatische Doppeldrucke nach einer Unterbrechung.
- Korrigierte Bluetooth-Rasterübertragung, gezielte Berechtigungsabfrage und direkt erreichbare Druckerverbindung.
- Native macOS-Oberfläche mit aktueller Systemdarstellung und neuem, schlichtem Etiketten-Icon.
- Etsy-CSV-Dateien mit Windows-Zeilenumbrüchen werden korrekt gelesen.

## Installation

`LabelHelper-universal.zip` herunterladen, entpacken und **Label Helper.app** in **Programme** verschieben. Die App enthält Intel- und Apple-Silicon-Code und benötigt macOS 14 oder neuer. Eine vorhandene Munbyn-Labeler-App kann bei geschlossenem Programm durch Label Helper ersetzt werden.

Die App ist derzeit ad hoc signiert und nicht von Apple notarisiert. macOS kann beim ersten Öffnen eine Freigabe unter **Systemeinstellungen → Datenschutz & Sicherheit → Dennoch öffnen** verlangen. Ohne feste Apple-Signieridentität kann macOS nach einem App-Wechsel erneut um Bluetooth-Zugriff bitten.

Die Browser-Erweiterung steht separat als `LabelHelper-Browser-Extension.zip` bereit. Die App enthält den bestehenden Sparkle-Updater mit signiertem Update-Feed.

## Prüfung

Universal-Build, Core-Regressionstests und Browser-Erweiterung werden im GitHub-Release-Workflow geprüft. Der Endlosablauf ist softwareseitig geprüft; die Ausgabe auf dem eigenen Drucker muss weiterhin am tatsächlichen Material kontrolliert werden. Gekaufte Marken wurden zur Release-Prüfung nicht physisch gedruckt.
