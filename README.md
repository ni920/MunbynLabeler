# Munbyn Labeler

Native macOS app for sending 4 × 6 inch labels to a MUNBYN RW403B over Bluetooth.

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

1. `MunbynLabeler-universal.zip` entpacken.
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
- discovers the writable GATT characteristic instead of assuming one firmware layout
- prefers the common TSPL print characteristic `FF02` when present
- generates a TSPL connection test label
- imports PDF, PNG and JPEG files
- rasterizes the first page at 203 dpi (800 × 1200 dots)
- transfers bitmap jobs in Bluetooth-sized chunks
- persists the print queue and prevents accidental duplicate imports
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
macOS runner. Successful runs retain a zipped app bundle as a private workflow
artifact for 14 days.

The workflow deliberately does not create a GitHub Release, upload to the App
Store, notarize the app or publish it anywhere. Distribution remains a separate
manual decision.

The repository also contains a dependency-free protocol self-test:

```bash
swift run LabelCoreSelfTest
```

The first Bluetooth scan triggers the macOS Bluetooth permission dialog. The app bundle contains the required privacy descriptions.

## First printer test

1. Turn on the RW403B and keep it close to the Mac.
2. Open **Drucken** and select **Geräte suchen**.
3. Connect to the device whose name contains `RW403B`.
4. If the state becomes **Drucker verbunden**, choose **Testetikett**.
5. If no writable channel is found, copy the entries from **Bluetooth-Diagnose**. They identify whether this firmware needs a serial Bluetooth transport instead of BLE GATT.

No real print is performed during automated tests. Physical output, orientation, density and the printer firmware's exact Bluetooth profile must be verified with the device present.
