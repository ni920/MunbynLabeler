# Label Helper

Native macOS app for preparing address and parcel labels and sending them to a
MUNBYN RW403B over Bluetooth.

Die App hieß zuvor **Munbyn Labeler**. Neue Builds heißen **Label Helper**;
das macOS-App-Paket heißt `Label Helper.app`. Beim manuellen Umstieg die alte
App beenden, die neue App nach **Programme** kopieren und anschließend die alte
`MunbynLabeler.app` entfernen. Einstellungen, Briefmarkenbestand und Druckhistorie
werden automatisch weiterverwendet. Bestehende Etsy-Erweiterungen öffnen die
umbenannte App weiterhin über den bisherigen Link.

The packaged app is a Universal 2 application containing native `arm64` and
`x86_64` binaries. It runs on Apple Silicon and Intel Macs with macOS 14 or
newer.

## Haftungsausschluss und Eigenverantwortung

Label Helper ist ein privates, unabhängiges Softwareprojekt und kein
offizielles Produkt von MUNBYN, Etsy oder DHL. Die Software wird unentgeltlich
und ohne Zusicherung bestimmter Eigenschaften bereitgestellt. Die Nutzung
erfolgt auf eigene Gefahr.

Es wird insbesondere keine Gewähr für Fehlerfreiheit, dauerhafte
Verfügbarkeit, Gerätekompatibilität, korrekte Adressübernahme, passende
Etikettenmaße, ausreichende Druckqualität oder die Annahme und Zustellung einer
Sendung übernommen. Vor dem Aufkleben oder Versenden müssen Adresse,
Absenderangaben, Porto, Barcodes, Etikettenformat und Druckbild vom Benutzer
kontrolliert werden. Kosten oder Schäden durch Fehldrucke, falsch adressierte
oder nicht zustellbare Sendungen, unzureichende Frankierung, Datenverlust sowie
eine fehlerhafte Bedienung von Drucker oder Versanddienst entstehen in der
Verantwortung des Benutzers.

Soweit gesetzlich zulässig, ist die Haftung des Autors für Schäden aus der
Nutzung oder Nichtverfügbarkeit der Software ausgeschlossen. Dieser Ausschluss
gilt nicht bei Vorsatz oder grober Fahrlässigkeit, bei Schäden aus der
Verletzung von Leben, Körper oder Gesundheit, bei der Verletzung wesentlicher
Vertragspflichten, im Anwendungsbereich zwingender gesetzlicher Haftung oder
soweit ausdrücklich eine Garantie übernommen wurde. Bei leicht fahrlässiger
Verletzung wesentlicher Vertragspflichten ist die Haftung auf den
vertragstypischen, vorhersehbaren Schaden begrenzt.

Dieser Hinweis ersetzt keine individuelle Rechtsberatung.

## Installation

### Voraussetzungen

- Intel-Mac oder Apple-Silicon-Mac
- macOS 14 oder neuer
- Bluetooth für die Verbindung zum Etikettendrucker

Für beide Prozessorarten wird dieselbe Universal-App verwendet.

### Installation aus dem ZIP-Archiv

1. Unter [GitHub Releases](https://github.com/ni920/MunbynLabeler/releases/latest)
   die Datei `LabelHelper-universal.zip` herunterladen und entpacken.
2. `Label Helper.app` in den macOS-Ordner **Programme** ziehen.
3. **Label Helper** aus dem Programme-Ordner öffnen.
4. Beim ersten Druckerversuch den Bluetooth-Zugriff erlauben.

Ältere GitHub-Releases enthalten noch `MunbynLabeler-universal.zip` und
`MunbynLabeler.app`. Die neuen Dateinamen gelten ab der nächsten Veröffentlichung.

Die App benötigt keinen klassischen Installer und installiert keine
Systemerweiterungen oder Hintergrunddienste.

### Bluetooth-Freigabe und lokale Entwicklungsbuilds

Die App fragt bei noch offener Berechtigung erst nach Bluetooth-Zugriff, wenn
**Drucker suchen** gewählt wird. Eine bereits erlaubte Installation verbindet
den gespeicherten Drucker weiterhin automatisch. Bei verweigertem Zugriff steht
der nächste Schritt direkt im Verbindungsfenster.

Lokale Builds sind standardmäßig **ad hoc signiert**. Dabei identifiziert macOS
jeden geänderten Programmstand über dessen Hash. Deshalb kann die Bluetooth-
Freigabe nach einem neu gebauten Update erneut erscheinen, auch bei gleicher
Bundle-ID und gleichem Namen. Ein unveränderter Build benötigt diese erneute
Freigabe normalerweise nicht. Siehe [Apples Erklärung zu Designated Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).

Für eine feste Signatur kann beim Bauen eine vorhandene **Apple Development**-
oder **Developer ID Application**-Identität übergeben werden:

```bash
LABEL_HELPER_CODE_SIGN_IDENTITY='Name der vorhandenen Signieridentität' ./script/build_and_run.sh build
```

Das Zertifikat muss mit privatem Schlüssel im Schlüsselbund vorhanden sein und
bei Folgeversionen gleich bleiben. Die Einstellung erstellt kein Zertifikat und
verändert keine Datenschutzfreigaben. Notarisierung für die öffentliche Verteilung
bleibt ein eigener Schritt. Auf diesem Mac war bei der Prüfung kein gültiges
Codesigning-Zertifikat vorhanden.

### Liquid Glass und ältere Macs

Die App nutzt die nativen Materialien von Seitenleiste, Symbolleiste und
System-Controls. Mit einem Build-SDK ab macOS 26 erscheint dort Liquid Glass;
macOS 14/15 verwenden weiterhin ihre jeweilige Systemdarstellung. Papier und
Adressinhalt bleiben normale, gut lesbare Inhaltsflächen.

Das Build-Script übergibt das ausgewählte SDK explizit an SwiftPM. Auf der
lokalen Command-Line-Tools-Installation wird das vorhandene SDK 26.5 genutzt,
weil im 27er-CLT das SwiftUI-State-Makro-Plugin fehlt. Eine vollständige
Xcode-Installation verwendet ihr ausgewähltes SDK. Das Laufzeitminimum bleibt
macOS 14, für Intel und Apple Silicon.

### App-Icon und Icon Composer

Das Icon zeigt ein Versandetikett mit einer abziehbaren Ecke. Die Vektorvorlage
besteht aus den Ebenen **Label**, **Peel** und **Address**. Die bearbeitbare
Icon-Composer-Datei liegt unter `Resources/AppIcon.icon` und enthält Vorgaben
für normale, dunkle und monochrome Darstellung.

Erstellt und mit Schema-/Asset-Prüfung validiert wurde sie mit dem ausdrücklich
verwendeten [Icon-Composer-Skill von giginet](https://github.com/giginet/apple-icon-composer-skill/tree/43b96bf200e088149abef29a1b999c70589bed81/plugins/icon-composer/skills/compose-app-icon).
Die Originalgrafik wird reproduzierbar aus `script/create_icon_artwork.swift`
erzeugt. Es werden keine fremden Symbole, Schriftzeichen oder Bilder benötigt.

Der Build erstellt weiterhin `AppIcon.icns` für macOS 14/15 und Builds ohne
vollständiges Xcode. Wenn `xcrun --find actool` verfügbar ist, kompiliert er
zusätzlich das mehrschichtige `.icon` in `Assets.car`. `CFBundleIconName` bleibt
`AppIcon`. Fehler dieser nativen Kompilierung stoppen den Build.

Auf diesem Mac fehlen Icon Composer / `ictool` und `actool`. Der lokale Build
verwendet deshalb das neue **statische ICNS**. Die native Glasdarstellung und
systemgesteuerten Varianten konnten hier noch nicht mit Apples Renderer geprüft
werden; die vorhandenen PNG-Vorschauen sind eigene kompatible Darstellungen.
Die Schema- und Asset-Validierung mit dem Skill ist erfolgreich.

### Erster Start und Gatekeeper

Die derzeitigen lokalen Builds sind ad-hoc signiert, aber noch nicht mit einer
Apple Developer ID signiert oder von Apple notarisiert. macOS kann die App beim
ersten Start deshalb zunächst blockieren.

Wenn die App aus einer vertrauenswürdigen Quelle stammt und der erste Start
blockiert wird:

1. Einmal versuchen, `Label Helper.app` zu öffnen.
2. **Systemeinstellungen → Datenschutz & Sicherheit** öffnen.
3. Zum Abschnitt **Sicherheit** scrollen.
4. Bei Label Helper **Dennoch öffnen** auswählen.
5. Die erneute Sicherheitsabfrage mit **Öffnen** bestätigen.

macOS speichert diese Ausnahme anschließend für die App. Apples aktuelle
Beschreibung dieses Ablaufs befindet sich unter
[Sicher Apps auf dem Mac öffnen](https://support.apple.com/de-de/102445).

Sicherheitswarnungen sollten nur für eine App übergangen werden, deren Herkunft
und Unversehrtheit bekannt sind.

### Aktualisierung

Version 0.6.3 enthält den signierten Sparkle-Updater und bezieht den öffentlichen
Update-Feed aus dem jeweils neuesten GitHub-Release. Von älteren Versionen, bei
denen der automatische Abruf noch nicht funktioniert, muss Version 0.6.3 einmal
manuell installiert werden:

1. Label Helper beenden.
2. Das neue ZIP-Archiv entpacken.
3. Die neue `Label Helper.app` über die vorhandene App im Programme-Ordner
   kopieren und **Ersetzen** bestätigen.

Danach kann der integrierte Updater weitere Versionen übernehmen. Update-Archive
und der Update-Feed werden mit einem separaten Sparkle-Ed25519-Schlüssel
signiert. Ein persönlicher GitHub-Zugriffsschlüssel wird weder in der App
gespeichert noch verteilt.

Die Druckwarteschlange bleibt bei einem App-Update erhalten, da sie getrennt
von der App unter folgendem Pfad gespeichert wird:

```text
~/Library/Application Support/MunbynLabeler/print-jobs.json
```

### Deinstallation

1. Label Helper beenden.
2. `Label Helper.app` aus dem Programme-Ordner in den Papierkorb verschieben.

Die lokale Druckhistorie bleibt dabei unter
`~/Library/Application Support/MunbynLabeler/` erhalten. Dieser Ordner kann
separat entfernt werden, wenn auch die lokalen App-Daten gelöscht werden sollen.

### Spätere Verteilung

Für den aktuellen Eigengebrauch genügt das ZIP-Archiv. Für eine komfortablere
Weitergabe kann später ein DMG mit der üblichen Drag-and-drop-Installation
erstellt werden:

```text
[Label Helper]  →  [Programme]
```

Eine Veröffentlichung ohne Gatekeeper-Sonderfreigabe benötigt außerdem eine
Apple-Developer-Mitgliedschaft, eine Developer-ID-Signatur und die
Notarisierung durch Apple. Weitere Informationen:
[Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Current prototype

- shows only discovered `RW403B` printers or devices advertising the compatible
  `ABF0` printer service instead of listing every nearby Bluetooth device
- remembers a successfully verified printer and reconnects automatically after
  a radio interruption, printer sleep or app restart
- contains Sparkle support for signed automatic updates; the current private
  GitHub release feed still requires manual installation until a separate
  public feed is available
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
- prepares 100-mm continuous-roll layouts: letters use 100 × 55 mm and parcels use 100 × 150 mm; physical printing requires the RW403B USB driver with media type Continuous
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

The finished bundle is written to `dist/Label Helper.app`. The build script
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
**An Label Helper senden**. Nach dem Klick öffnet macOS die lokal installierte
App oder bringt das bereits geöffnete App-Fenster nach vorne. Sie erzeugt dabei
kein weiteres Munbyn-Labeler-Fenster. Dort werden nur Bestellnummer und
Empfänger angezeigt und erst nach der Auswahl **Brief** oder **Paket**
übernommen. Artikeldaten werden weder ausgelesen noch an die App übertragen. Es
wird niemals automatisch gedruckt.

Die Daten werden ausschließlich über den lokalen App-Link
`munbyn-labeler://etsy-order` übertragen. Ein externer Server ist nicht
beteiligt. Der Absender wird nicht aus Etsy übernommen, sondern einmalig unter
**Label Helper → Einstellungen … → Allgemein** gespeichert.

### Chrome

1. Im passenden GitHub Release `LabelHelper-Browser-Extension.zip`
   herunterladen und entpacken.
2. `chrome://extensions` öffnen und **Entwicklermodus** aktivieren.
3. **Entpackte Erweiterung laden** wählen.
4. Den entpackten Ordner `BrowserExtension` auswählen.
5. Eine Etsy-Bestellung öffnen, sodass rechts das Bestellpanel mit
   **Versand an** und der vollständigen Adresse sichtbar ist, und
   **An Label Helper senden** anklicken.

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

Unter **Etikettenmaterial** kann zwischen vorgestanzten Etiketten und einer
**100-mm-Endlosrolle** gewählt werden. Im Endlosmodus erzeugt die App ein
Briefetikett mit **100 × 55 mm** und ein Paketetikett mit **100 × 150 mm**.
Damit kann dieselbe Rolle für beide Versandarten im Drucker bleiben. Da der
RW403B keinen automatischen Schneider besitzt, wird das Endlosetikett nach dem
Druck manuell an der gedruckten Schnittlinie getrennt. Unter jedem Endlosetikett
fügt die App eine gestrichelte Linie auf **2 mm zusätzlichem Rand** hinzu.
Adresse, Internetmarke und DHL-Barcodes bleiben in ihrer Größe erhalten und
werden von der Linie nicht überdeckt. Briefetiketten sind damit **100 × 57 mm**,
Paketetiketten **100 × 152 mm** lang. Die Vorschau und der Testdruck zeigen dieselbe
Linie wie der tatsächliche Ausdruck; auch bei Adresse + Briefmarke erhält jedes
Etikett eine eigene Linie. Bei vorgestanzten Etiketten entfällt dieser Zusatzrand.

Bei älteren Firmware-Versionen kann die automatische Lückensuche mit
unmarkiertem Endlosmaterial dauerhaft vor- und zurückfahren. Die App gibt
Endlosdruck über Bluetooth deshalb erst frei, wenn der verbundene RW403B eine
**Firmware ab 1.1.49** meldet. Die Versionsnummer stammt aus dem Geräte-Handshake,
nicht aus einer manuell gesetzten Einstellung; bei Trennung wird sie verworfen.
Ältere, fehlende oder unlesbare Versionsangaben behalten die Bluetooth-Sperre.

Mit dieser Freigabe verwenden Adress- und Paketetiketten den normalen,
bestätigten Bluetooth-Rasterdruck. Vor jedem Auftrag wird keine zusätzliche
Papierkalibrierung ausgelöst. Der Firmware-Wechsel muss trotzdem einmal mit der
tatsächlich eingelegten unmarkierten Rolle geprüft werden. Der Endlos-Testdruck
ist immer **100 × 55 mm plus 2 mm Schnittzugabe**, auch wenn zuletzt Paketversand gewählt war.

Ohne passende Firmware bleibt USB/Systemdruck als Alternative; im RW403B-Treiber
muss der Medientyp **Endlos/Continuous** eingestellt sein. Vorgestanzte Etiketten
werden weiterhin direkt per Bluetooth gedruckt. Briefmarken-Bündel und kombinierte
Adresse-/Briefmarkenabläufe können ebenfalls auf der Endlosrolle vorbereitet werden.
Ihr Druck benötigt den bestätigten Bluetooth-Druckweg mit Firmware ab 1.1.49;
für gekaufte Marken gibt es keinen automatischen USB-Ausweichdruck.

Die Endlosrolle wird von außen zugeführt und die Papierführungen werden auf die
Rollenbreite eingestellt. Die normale FEED-Kalibrierung für Lückenetiketten darf
mit einer Endlosrolle nicht gestartet werden, weil der Sensor dort keine Lücke
finden kann.

Bei vorgestanzten Etiketten wird das kleinere Briefformat auf der Seite
**Drucken** ausgewählt und gilt für neu erstellte Etsy-Adressetiketten.
**89 × 36 mm** ist die Standardgröße. Für Briefe stehen vier kompakte Vorlagen
sowie **Eigenes Format** zur Verfügung. Bereits in der Warteschlange liegende
Aufträge behalten ihre ursprüngliche Größe.

DHL-Paketlabel werden unabhängig vom Briefformat immer als **100 × 150 mm**
importiert. Die Breite eigener Formate ist auf den Druckbereich des RW403B von
maximal 108 mm begrenzt. PDF- und Bildinhalte werden proportional eingepasst
und nicht verzerrt. Das Testetikett verwendet bei vorgestanztem Material das Format der aktuellen
Versandart; bei Endlosmaterial bleibt es auf 100 × 55 mm plus 2 mm Schnittzugabe begrenzt.

Die typische DHL-Paketmarke als A4-PDF enthält oben das eigentliche Versandlabel
und unten eine Sendungsinformation. Beim Paketimport erkennt die App dieses
Layout automatisch, entfernt den unteren Beleg sowie die Schnittlinie, dreht
die Paketmarke und passt nur diesen Ausschnitt auf 100 × 150 mm ein. Bereits
passend erzeugte 100 × 150-mm-PDFs werden unverändert übernommen.

## Briefmarken-Bündel platzsparend drucken

Unter **Briefmarken → PDF-Bündel importieren …** können gekaufte Internetmarken
aus einem PDF-Bogen übernommen werden. Unterstützt wird das kompakte
Deutsche-Post-Layout ohne Motiv oder Anschrift, auch mit mehreren PDF-Seiten.
Der normale PDF-Import erkennt solche Bündel ebenfalls und öffnet den
Briefmarkenbereich.

1. Verfügbare Marken auswählen und das tatsächlich eingelegte Etikettenformat wählen.
2. Bei Bedarf **Schnittlinien** aktivieren und **Druckvorschau erstellen** anklicken.
3. Alle erzeugten Etiketten in der Vorschau durchblättern.
4. Den RW403B verbinden und den Druck starten. Anschließend die Marken ausschneiden.

Die App packt mehrere Marken auf jedes Etikett. Beim kompakten Beispiel-Layout
passen vier Marken auf 100 × 50 mm; ein Zehnerbündel passt auf 100 × 150 mm.
Barcode, Logo, Porto und Kennung bleiben zusammen und werden in ihrer
Originalgröße gedruckt. Die Deutsche Post empfiehlt
[Tatsächliche Größe](https://www.deutschepost.de/de/i/internetmarke-porto-drucken/haeufige-fragen/drucken.html).
Zu kleine Formate werden abgewiesen, statt die Marken zu verkleinern.
Die Rastervorschau entspricht den 203-dpi-Druckdaten des RW403B.

In der Markenliste und der Druckvorschau steht die vollständige 20-stellige
**Sendungsnummer** mit Kopierbutton. Kopiert wird die Nummer ohne Leerzeichen,
einschließlich führender Nullen und der letzten Prüfziffer. **Nummern der Auswahl
kopieren** beziehungsweise **Nummern dieses Etiketts kopieren** legt mehrere
Nummern in Druckreihenfolge, jeweils in einer eigenen Zeile, in die Zwischenablage.
Die Einzelnummer bleibt auch bei bereits gedruckten Marken kopierbar.
Bei gewöhnlichen Internetmarken ist dies die
[Basis-Sendungsverfolgung](https://www.deutschepost.de/de/hilfe-kundenservice/versenden/frankierung/matrixcode/hilfe-zum-matrixcode-sendungsverfolgung.html)
mit Bearbeitung im Briefzentrum, ohne Zustellnachweis.

Die Quelldateien und der Markenbestand werden lokal unter
`~/Library/Application Support/MunbynLabeler/Briefmarken/` gespeichert.
Erneutes Importieren erkennt dieselben Marken anhand ihrer Kennung und setzt
gedruckte Marken nicht zurück. Diese Historie bleibt auch nach dem Leeren der
Warteschlange erhalten. Ein unterbrochener oder nicht bestätigter Druck wird als
**Ausdruck prüfen** markiert. Danach kann die Marke als gedruckt bestätigt oder,
nach Kontrolle des Ausdrucks, wieder freigegeben werden. Der Status dokumentiert
den lokalen Druck; er prüft keine postalische Einlösung der Marke.

Mehrere Etiketten werden nacheinander übertragen. **Nach diesem Etikett stoppen**
beendet die Serie nach dem laufenden Etikett. Unter **Material** können auch
100-mm-Endlosrollen gewählt werden; dafür stehen 100 mm breite Formate zur Auswahl.
Die Vorschau funktioniert ohne Druckerverbindung, der Endlosdruck benötigt Firmware ab 1.1.49.

## Geführter Modus

Beim ersten Start ist unter **Versenden** der geführte Modus aktiv. Oben lässt
sich jederzeit zwischen **Geführt** und **Direkt** wechseln. Die App merkt sich
die Auswahl; dieselbe Option steht unter **Einstellungen → Allgemein → Bedienung**.

Die Startseite **Neuer Versand** fragt **Was möchtest du drucken?**:

- **Brief versenden:** Empfänger eingeben oder aus Etsy übernehmen, nur Adresse
  oder Adresse + Briefmarke wählen, eingelegtes Etikettenformat prüfen und die
  Druckvorschau öffnen. Der Absender wird einmal in den Einstellungen hinterlegt.
- **Paketlabel drucken:** Ein gekauftes DHL-Label auswählen und vor dem Druck
  prüfen. Das Paketformat bleibt bei 100 × 150 mm.
- **Briefmarken drucken:** PDF-Bündel importieren oder vorhandene Marken nutzen,
  Marken auswählen, Format und Schnittlinien bestimmen und die Vorschau öffnen.

**Zurück** in der Symbolleiste erhält die Eingaben. **Andere Aufgabe auswählen**
führt zur Startseite zurück. **Weiter** bzw. **Vorschau** steht ebenfalls in der
Symbolleiste und ist über **Versand → Weiter / Vorschau öffnen** (⌘↩) erreichbar.
Mit **Versand → Aufgabe auswählen** (⇧⌘H) ist die Startseite auch über die Tastatur
erreichbar. Aus der Browser-Erweiterung bestätigte Bestellungen öffnen den
passenden Vorbereitungsschritt mit übernommener Adresse. Der Direktmodus zeigt
weiterhin alle Versandfelder zusammen.

Bereits bei der Adresseingabe erscheint das aktuelle Etikettenlayout, ohne einen
Druckauftrag anzulegen. Im breiten Fenster stehen Formular und Vorschau nebeneinander,
im schmalen Fenster untereinander. Die drei Druckvorschauen verwenden dieselbe
Papierdarstellung und passen zur macOS-Hell-/Dunkeldarstellung.

**Weiter** bereitet vor; gedruckt wird erst über den Druckbutton in der Vorschau.
Dort kann der Drucker auch direkt verbunden werden. Druckereinstellungen und
Bluetooth-Diagnose liegen unter **Label Helper → Einstellungen …** (⌘,).
Briefverlauf, Druckaufträge und Briefmarkenbestand bleiben über die Seitenleiste
erreichbar.

## Brief oder Paket vorbereiten

### Adresse und Briefmarke in einem Ablauf

Unter **Versenden → Direkt → Brief** kann **Adresse + Briefmarke** aktiviert werden.
Danach eine verfügbare Internetmarke mit dem passenden Portowert auswählen und
**Briefablauf prüfen** öffnen. Die Vorschau zeigt beide Etiketten einzeln:
zuerst die Empfängeradresse mit Absender, danach die ausgewählte Briefmarke in
Originalgröße. Beide verwenden das eingestellte Briefformat und dieselbe Rolle.

**Adresse + Briefmarke drucken** überträgt zuerst das Adressetikett und wartet
auf die Druckbestätigung. Anschließend wird die Briefmarke gedruckt. Die Marke
wird für diesen Brief reserviert und steht währenddessen nicht für einen
anderen Brief oder Bündeldruck zur Verfügung. Nach Abschluss erscheint die
Sendungsnummer mit Kopierbutton. Optional kann sie automatisch in die
Zwischenablage kopiert werden.

Unter **Briefverlauf** bleiben Empfänger, eine übernommene Etsy-Bestellnummer,
Briefmarke, Sendungsnummer und Druckfortschritt gespeichert. Bei einer Trennung
nach dem Adressdruck kann **Nur Briefmarke drucken** fortsetzen. Nach einem
unklaren Druck oder App-Abbruch wird zuerst nach dem tatsächlichen Ausdruck
gefragt. Eine bereits bestätigte Adresse wird nicht automatisch erneut
gedruckt; eine unklar gedruckte Marke wird nicht automatisch wiederverwendet.

Der Portowert wird vom Benutzer ausgewählt. Die App berechnet das Porto nicht
aus Etsy-Artikeln oder Gewicht. Der gemeinsame Ablauf verwendet den bestätigten
Bluetooth-Druckweg und funktioniert mit vorgestanzten Etiketten oder Endlosrolle
(ab Firmware 1.1.49). Die Briefmarkenauswahl wird für den nächsten App-Start gespeichert
und vor der Vorschau erneut auf Verfügbarkeit geprüft. Fehlt eine Marke, führt
**Frankierung bearbeiten** direkt zur Auswahl zurück.

Im Direktmodus wird auf der Seite **Versenden** zuerst **Brief** oder **Paket** gewählt.

Für einen Brief:

1. Empfänger und Absender direkt in das Formular eintragen.
2. **89 × 36 mm** ist vorausgewählt. Für Briefe werden nur die kleineren Adressformate angeboten; eine alte Auswahl von 100 × 150 mm wird automatisch auf 89 × 36 mm zurückgesetzt. Die App merkt sich das zuletzt verwendete Briefformat.
3. **Druckvorschau erstellen** auswählen.
4. Das gerasterte Etikett kontrollieren und **Jetzt drucken** auswählen.

Das Briefetikett verwendet eine kleine, vollständig eingepasste Absenderzeile
und einen kompakten Empfängerblock. Bei deutschen Inlandsadressen wird
**Deutschland** nicht mitgedruckt; bei Auslandsadressen bleibt das Zielland
erhalten.

Für ein Paket:

1. Das Versandlabel bei DHL kaufen und als PDF herunterladen.
2. **DHL-PDF auswählen …** anklicken.
3. Das importierte 100 × 150-mm-Label in der Druckvorschau kontrollieren.
4. **Jetzt drucken** auswählen.

Paketlabel bleiben unabhängig vom gewählten Briefformat fest auf **100 × 150 mm**.

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
6. If the connection fails, open **Label Helper → Einstellungen …** (`⌘,`),
   switch to **Bluetooth** and copy the entries from the diagnostic log.

After the first successful connection, the app remembers the verified RW403B
and reconnects it automatically. Choosing **Trennen** disables that behavior
until a printer is connected manually again.

## Einstellungen

Open **Label Helper → Einstellungen …** or use `⌘,`. The **Allgemein** tab
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
8. Reconnect in Label Helper. The paper warning should disappear before
   **Testetikett** is pressed.

MUNBYN's official instructions are available in
[RW403B sensor calibration](https://support.munbyn.com/hc/en-us/articles/52525254689043-How-to-Fix-Red-Light-Paper-Recognition-Failure-via-Printer-Sensor-Calibration)
and
[label-size and paper learning](https://support.munbyn.com/hc/en-us/articles/41520136801299-How-to-create-a-new-customized-label-size).
