# Munbyn Labeler

Native macOS app for preparing address and parcel labels and sending them to a
MUNBYN RW403B over Bluetooth.

The packaged app is a Universal 2 application containing native `arm64` and
`x86_64` binaries. It runs on Apple Silicon and Intel Macs with macOS 14 or
newer.

## Installation

### Voraussetzungen

- Intel-Mac oder Apple-Silicon-Mac
- macOS 14 oder neuer
- Bluetooth für die Verbindung zum Etikettendrucker

Für beide Prozessorarten wird dieselbe Universal-App verwendet.

### Installation aus dem ZIP-Archiv

1. Unter [GitHub Releases](https://github.com/ni920/MunbynLabeler/releases/latest)
   die Datei `MunbynLabeler-universal.zip` herunterladen und entpacken.
2. `MunbynLabeler.app` in den macOS-Ordner **Programme** ziehen.
3. **Munbyn Labeler** aus dem Programme-Ordner öffnen.
4. Beim ersten Druckerversuch den Bluetooth-Zugriff erlauben.

Die App benötigt keinen klassischen Installer und installiert keine
Systemerweiterungen oder Hintergrunddienste.

### Erster Start und Gatekeeper

Die derzeitigen lokalen Builds sind ad-hoc signiert, aber noch nicht mit einer
Apple Developer ID signiert oder von Apple notarisiert. macOS kann die App beim
ersten Start deshalb zunächst blockieren.

Wenn die App aus einer vertrauenswürdigen Quelle stammt und der erste Start
blockiert wird:

1. Einmal versuchen, `MunbynLabeler.app` zu öffnen.
2. **Systemeinstellungen → Datenschutz & Sicherheit** öffnen.
3. Zum Abschnitt **Sicherheit** scrollen.
4. Bei Munbyn Labeler **Dennoch öffnen** auswählen.
5. Die erneute Sicherheitsabfrage mit **Öffnen** bestätigen.

macOS speichert diese Ausnahme anschließend für die App. Apples aktuelle
Beschreibung dieses Ablaufs befindet sich unter
[Sicher Apps auf dem Mac öffnen](https://support.apple.com/de-de/102445).

Sicherheitswarnungen sollten nur für eine App übergangen werden, deren Herkunft
und Unversehrtheit bekannt sind.

### Aktualisierung

1. Munbyn Labeler beenden.
2. Das neue ZIP-Archiv entpacken.
3. Die neue `MunbynLabeler.app` über die vorhandene App im Programme-Ordner
   kopieren und **Ersetzen** bestätigen.

Die Druckwarteschlange bleibt bei einem App-Update erhalten, da sie getrennt
von der App unter folgendem Pfad gespeichert wird:

```text
~/Library/Application Support/MunbynLabeler/print-jobs.json
```

### Deinstallation

1. Munbyn Labeler beenden.
2. `MunbynLabeler.app` aus dem Programme-Ordner in den Papierkorb verschieben.

Die lokale Druckhistorie bleibt dabei unter
`~/Library/Application Support/MunbynLabeler/` erhalten. Dieser Ordner kann
separat entfernt werden, wenn auch die lokalen App-Daten gelöscht werden sollen.

### Spätere Verteilung

Für den aktuellen Eigengebrauch genügt das ZIP-Archiv. Für eine komfortablere
Weitergabe kann später ein DMG mit der üblichen Drag-and-drop-Installation
erstellt werden:

```text
[Munbyn Labeler]  →  [Programme]
```

Eine Veröffentlichung ohne Gatekeeper-Sonderfreigabe benötigt außerdem eine
Apple-Developer-Mitgliedschaft, eine Developer-ID-Signatur und die
Notarisierung durch Apple. Weitere Informationen:
[Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Current prototype

- scans for nearby Bluetooth Low Energy devices
- prioritizes devices named `RW403B` or `MUNBYN`
- uses the RW403B BLE service `ABF0` with `ABF1` for control commands,
  `ABF3` for printer responses and `ABF4` for print data
- performs the required device-information handshake before enabling printing
- reads the printer status and reports conditions such as an open cover,
  overheating or paper that is not recognized
- encodes raster jobs with the MUNBYN message framing and Heatshrink compression
- waits for the printer acknowledgement after every raster section
- generates a real raster test label in the selected size
- imports PDF, PNG and JPEG files
- imports Etsy order CSV files and creates selectable sender/recipient labels
- receives the open Etsy order from the Chrome/Safari browser extension
- shows a review step for choosing letter or parcel before applying browser data
- previews the exact black-and-white 203-dpi raster before every label print
- offers presets for 100 × 150, 100 × 50, 89 × 36, 70 × 36 and 50 × 50 mm
- supports custom sizes from 20–108 mm wide and 15–300 mm high
- rasterizes each job at the RW403B resolution of 8 dots/mm (203 dpi)
- transfers bitmap jobs in BLE-sized packets
- stores the chosen format with every print job and prevents accidental duplicate imports
- records discovered services and characteristics for first-device diagnostics
- includes a custom macOS app icon
- builds as a Universal 2 app for Apple Silicon and Intel Macs

## Build and run

```bash
./script/build_and_run.sh
```

To create the app without launching it:

```bash
./script/build_and_run.sh build
```

The finished bundle is written to `dist/MunbynLabeler.app`. The build script
compiles both CPU architectures, combines them into one executable, generates
the `.icns` icon set and applies an ad-hoc local signature.

Verify both architectures, the signature and a local launch with:

```bash
./script/build_and_run.sh verify
```

## Continuous integration

`.github/workflows/build.yml` builds and verifies the Universal 2 app on a
macOS runner. Successful runs retain a zipped app bundle as a workflow artifact
for 14 days.

Pushing a version tag such as `v0.2.0` starts
`.github/workflows/release.yml`. That workflow repeats the tests and Universal
build, verifies the bundle, and publishes the ZIP plus its SHA-256 checksum as
a permanent GitHub Release. The release is ad-hoc signed and not Apple-notarized;
it is not uploaded to the App Store.

The repository also contains a dependency-free protocol self-test:

```bash
swift run LabelCoreSelfTest
```

The first Bluetooth scan triggers the macOS Bluetooth permission dialog. The app bundle contains the required privacy descriptions.

## Etsy-Browser-Erweiterung

Die Erweiterung ergänzt eine geöffnete Etsy-Bestellung um den Button
**An Munbyn Labeler senden**. Nach dem Klick öffnet macOS die lokal installierte
App. Dort werden Bestellnummer, Empfänger und erkannte Artikel angezeigt und
erst nach der Auswahl **Brief** oder **Paket** übernommen. Es wird niemals
automatisch gedruckt.

Die Daten werden ausschließlich über den lokalen App-Link
`munbyn-labeler://etsy-order` übertragen. Ein externer Server ist nicht
beteiligt. Der Absender wird nicht aus Etsy übernommen, sondern einmalig unter
**Munbyn Labeler → Einstellungen … → Allgemein** gespeichert.

### Chrome

1. Im passenden GitHub Release `MunbynLabeler-Browser-Extension.zip`
   herunterladen und entpacken.
2. `chrome://extensions` öffnen und **Entwicklermodus** aktivieren.
3. **Entpackte Erweiterung laden** wählen.
4. Den entpackten Ordner `BrowserExtension` auswählen.
5. Eine Etsy-Bestellung mit sichtbarer Versandadresse öffnen und
   **An Munbyn Labeler senden** anklicken.

### Safari

Chrome und Safari verwenden dieselben WebExtension-Dateien. Safari benötigt
für eine dauerhafte Installation zusätzlich eine kleine, mit Xcode erzeugte
Container-App. Aktuelle Safari-Versionen können den entpackten Ordner zum
Testen auch vorübergehend über den Developer-Tab laden. Für einen lokalen
Container-Build im Repository:

```bash
./script/create_safari_extension_project.sh
```

Danach das erzeugte Projekt in Xcode bauen und die Erweiterung unter
**Safari → Einstellungen → Erweiterungen** einschalten. Für eine regulär
signierte Safari-Veröffentlichung ist eine Apple-Developer-Mitgliedschaft
erforderlich.

## Etikettenformate

Das Format wird auf der Seite **Drucken** vor dem Import ausgewählt. Es gilt für
neu importierte Dateien, Etsy-Adressetiketten und das Testetikett. Bereits in
der Warteschlange liegende Aufträge behalten ihre ursprüngliche Größe.

Neben den fünf Vorlagen kann **Eigenes Format** gewählt werden. Die Breite ist
auf den Druckbereich des RW403B von maximal 108 mm begrenzt. PDF- und
Bildinhalte werden proportional eingepasst und nicht verzerrt.

## Brief oder Paket vorbereiten

Auf der Seite **Drucken** wird zuerst **Brief** oder **Paket** gewählt.

Für einen Brief:

1. Empfänger und Absender direkt in das Formular eintragen.
2. Das passende Etikettenformat auswählen.
3. **Druckvorschau erstellen** auswählen.
4. Das gerasterte Etikett kontrollieren und **Jetzt drucken** auswählen.

Für ein Paket:

1. Das Versandlabel bei DHL kaufen und als PDF herunterladen.
2. **DHL-PDF auswählen …** anklicken.
3. Das importierte 100 × 150-mm-Label in der Druckvorschau kontrollieren.
4. **Jetzt drucken** auswählen.

Der Etsy-CSV-Import ist optional. Mit **Aus Etsy-CSV übernehmen …** kann die
Empfängeradresse einer Bestellung ins Brief-Formular übernommen werden. Dazu in
Etsy **Shop-Manager → Einstellungen → Optionen → Daten herunterladen** öffnen,
unter **Bestellungen** den CSV-Typ **Bestellungen** wählen und die Datei laden.

Die aktuelle Etsy-Anleitung für den Export befindet sich unter
[How Do I Download My Etsy Data?](https://help.etsy.com/hc/en-us/articles/360035753053-How-Do-I-Download-My-Etsy-Data).

Eine Etsy-CSV enthält keine gekaufte DHL-Frankierung. Für **DHL-Paketlabel**
muss das Label weiterhin bei DHL gekauft und anschließend als PDF importiert
werden. Etsy-CSV und erzeugte Adressetiketten werden ausschließlich lokal
verarbeitet. Die PDFs liegen unter:

```text
~/Library/Application Support/MunbynLabeler/Address Labels/
```

## First printer test

1. Turn on the RW403B and keep it close to the Mac.
2. Open **Drucken** and select **Geräte suchen**.
3. Connect to the device whose name contains `RW403B`.
4. Wait until the state becomes **Drucker verbunden**. The line below it also
   shows the status reported by the printer.
5. If no warning is shown, choose **Testetikett**.
6. If the connection fails, open **Munbyn Labeler → Einstellungen …** (`⌘,`),
   switch to **Bluetooth** and copy the entries from the diagnostic log.

## Einstellungen

Open **Munbyn Labeler → Einstellungen …** or use `⌘,`. The **Allgemein** tab
contains the print speed, density, default label format and sender address. The
**Bluetooth** tab contains the live connection state, device search and the
copyable Bluetooth diagnostic log.

The BLE transport and the device-information handshake have been verified with
a real `RW403B-NE801`: the printer acknowledges both control commands with
status `200`. During initial integration the device reported an unrecognized
paper roll and an open cover; the app correctly blocked raster transfer and
surfaced both conditions instead of reporting a false success.

## Troubleshooting: Papier wird nicht erkannt

If the app shows **Papier wird nicht erkannt**, Bluetooth is already working.
The message comes directly from the RW403B status response. Calibrate the paper
sensor before trying another test label:

1. Switch the printer off and remove the labels.
2. Hold the **FEED** button while switching the printer on.
3. Release **FEED** immediately after the beep.
4. Let the automatic calibration finish without pressing another button.
5. After the printer stops, wait five seconds and restart it.
6. Load at least eight consecutive labels, guide them straight through the
   paper guides and close the cover.
7. Hold **FEED** until the printer beeps so it can learn the label gap.
8. Reconnect in Munbyn Labeler. The paper warning should disappear before
   **Testetikett** is pressed.

MUNBYN's official instructions are available in
[RW403B sensor calibration](https://support.munbyn.com/hc/en-us/articles/52525254689043-How-to-Fix-Red-Light-Paper-Recognition-Failure-via-Printer-Sensor-Calibration)
and
[label-size and paper learning](https://support.munbyn.com/hc/en-us/articles/41520136801299-How-to-create-a-new-customized-label-size).
