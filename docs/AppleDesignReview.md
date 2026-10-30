# Label Helper: macOS-Designprüfung und Überarbeitung

## Kontext und Urteil

Native SwiftUI-App für kleine Etsy-Versender. Ein Versand wird vorbereitet und anschließend auf einem Thermoetikett geprüft. Ausgangsurteil: **Needs work**. Die bisherige Startseite besteht aus drei sehr breiten Standardbuttons; innerhalb der Schritte stehen Text, Formular und Hinweise ohne klare gemeinsame Ausrichtung. Die vorhandene native Seitenleiste, die getrennten Settings und der sichere Vorschau-/Druckablauf bleiben erhalten.

Apple Design wurde mit zwölf lokalen HIG-Referenzen geprüft: accessibility, layout, typography, color, designing-for-macos, toolbars, sidebars, buttons, entering-data, lists-and-tables, dark-mode und materials sowie dem Code-Audit. Zusätzlich wurden am 30.10.2026 die aktuellen Markdown-Fassungen von Apple für Layout, macOS, Materialien und Toolbars abgerufen. Die Aussagen unten wurden darin erneut geprüft.

## Befunde vor der Änderung

- **High – Proportionen und Ausrichtung:** `GuidedShippingView.swift:29` und `:80` strecken die Aufgaben zu breiten Tasten und verteilen kurze Inhalte über ein fast leeres Fenster. `layout.md › Visual hierarchy`: “Align elements to make them easier to scan”. Entscheidung: begrenzte, zentrierte Arbeitsfläche; kompakte Aufgabenauswahl; zusammengehörige Inhalte in einer Formulargruppe.
- **High – Navigation am unteren Fensterrand:** `GuidedShippingView.swift:268` verankert die einzige Weiter-Aktion ganz unten. `layout.md › Desktop (macOS)`: “Avoid placing controls or critical information at the bottom of a window.” Entscheidung: Navigation direkt unter dem Formular in derselben lesbaren Spalte, statt großer leerer Zwischenfläche.
- **Medium – Uneinheitliche Vorschauen:** `PrintPreviewView.swift:20`, `LetterFlowView.swift:28` und `PostageBundleView.swift:148` verwenden verschiedene Hintergründe, Abstände und Schatten. Designurteil: gemeinsame Papierdarstellung mit zurückhaltendem Schatten und einheitlicher Seitenstruktur.
- **Medium – Wiederholte Überschriften und Textblöcke:** `ShippingFormView.swift:15` plus zusätzliche GroupBox-Titel und Erklärungen. `lists-and-tables.md › Content`: “Keep item text succinct”. Entscheidung: kürzere Labels, native Formularabschnitte, technische Details aufklappbar.
- **Medium – Inhalts- und Kontrollschicht:** keine eigenen glassEffect-Flächen vorhanden. Apple `materials.md › Liquid Glass`: “Use Liquid Glass effects sparingly.” System-Sidebar und Toolbar zeichnen ihre Materialien selbst. Inhaltsflächen bleiben ruhig und lesbar; kein zusätzliches Glas.

## Gestaltungsplan vor der Umsetzung

**These:** Eine ruhige Mac-Druckwerkstatt: links Versandaufgaben, in der Mitte ein klar begrenztes Formular, im Briefschritt ein echtes, aus den aktuellen Eingaben erzeugtes Etikettenlayout. Papier und Adresssatz bilden die Produktsprache.

**Schrift:** SF Pro über SwiftUI-Textstile. Einstieg 26 pt semibold, Schritttitel 20 pt semibold, Abschnitte/Zeilen 13 pt semibold, Inhalt 13 pt regular, Zusatztexte 12 pt regular. SF Mono nur für Sendungsnummern. Keine beliebige Displayschrift und keine iOS-Dynamic-Type-Zusage auf macOS.

**Farben:** dynamische macOS-Rollen. Referenzwerte aus AppKit/sRGB auf diesem Mac, keine hart codierten Nachbauten von Systemfarben:

| Rolle | Hell | Dunkel | Kontrast zur Fensterfläche hell / dunkel |
|---|---|---|---|
| Fensterfläche | #FFFFFF | #1E1E1E | Referenzfläche |
| Inhalt | #272727 | #DDDDDD | 14,94:1 / 12,23:1 |
| Zusatzinformation | #808080 | #9A9A9A | 3,95:1 / 5,89:1 |
| Akzent | #007AFF | #007AFF | 4,02:1 / 4,15:1 |
| Bedruckbares Papier / Druckfarbe | #FFFFFF / #000000 | #FFFFFF / #000000 | 21:1 |

Die niedriger kontrastierende sekundäre Textfarbe wird nur für Zusatzinformation verwendet. Schritte, Pflichtfeldhinweise und notwendige Anweisungen verwenden primären Text; Systemfarben reagieren auf erhöhten Kontrast. Weißes Papier ist tatsächlicher Druckinhalt und bleibt auch im Dunkelmodus weiß. Akzentfarbe kennzeichnet Interaktion; Status verwendet zusätzlich Text und Symbol.

**Layout:** Inhalt auf 640–760 pt begrenzen, mittig im Detailbereich; native Formulare und ein konsistentes Raster aus 8/12/16/24/32 pt. Arbeitsnavigation unmittelbar beim Inhalt.

```text
Regulär                              Kompakt
Sidebar |       Neuer Versand        Sidebar | Neuer Versand
        | [Brief] [Paket] [Marken]            | [Brief / Paket / Marken]
        | Etsy-Adresse übernehmen             | Etsy-Adresse übernehmen

Sidebar | Brief · 1 von 4            Sidebar | Brief · 1 von 4
        | Empfänger                          | Empfänger
        | [native Formulargruppe]            | [native Formulargruppe]
        | [echtes Etikettenlayout]           | [Etikettenlayout]
        | Zurück                Weiter       | Zurück          Weiter
```

**Signatur:** Das eigene, tatsächlich gesetzte Briefetikett erscheint bereits während der Vorbereitung als Papierobjekt. Es ist mit derselben PDF-Satzfunktion wie der Druck verbunden, keine beliebige Illustration und keine Beispieladresse. Dieser Plan würde für eine beliebige Aufgaben-App keinen Sinn ergeben und bleibt daher produktspezifisch.

**Bewegung:** keine dekorative Animation. Native Press-/Hover-/Fokuszustände. Keine eigene Transparenzschicht; Reduce Transparency wird vom System gehandhabt.

**Kritik und Reduktion:** Die vorherige langgezogene Liste großformatiger Buttons wirkt wie ein Assistent aus einer Webseite. Entfernt werden die große Footer-Leiste und redundante Überschriften. Die native Fenster- und Seitenleistenstruktur bleibt. Der sichere Druckabschluss bleibt unverändert.

## Prüfung

Build und lokale Oberflächenprüfung folgen nach Umsetzung. Farben werden nicht aus Screenshots geschätzt. Bildschirmleser-Beschriftungen werden im Accessibility-Baum geprüft; dies ersetzt keine vollständige VoiceOver-Sitzung.

Aktuelle Quellen: [Apple Layout](https://developer.apple.com/design/human-interface-guidelines/layout), [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars), [Materials](https://developer.apple.com/design/human-interface-guidelines/materials).


## Liquid Glass und Bluetooth: ergänzende Prüfung

Die ursprüngliche fertige Universal-Datei meldete in **beiden** Architekturen `minos 14.0 / sdk 14.0`. Das erklärte die ältere Systemdarstellung trotz aktueller macOS-Version. Der Build trennt nun Mindestversion und tatsächliches SDK auch in den Linkerargumenten. Das 27er-CLT-SDK konnte wegen eines fehlenden SwiftUI-State-Makro-Plugins nicht verwendet werden; SDK 26.5 wurde vollständig gebaut. `vtool` bestätigt anschließend **arm64 und x86_64: minos 14.0 / sdk 26.5**. Eine neue Build-Prüfung verhindert einen erneuten falschen SDK-Eintrag. Native Toolbars, Sidebars und Controls übernehmen Liquid Glass auf unterstützten Systemen. Inhaltskarten und Druckpapier erhalten keine Glasschicht.

Bluetooth war im Service-Konstruktor sofort initialisiert. Die App ist außerdem ad hoc signiert: `codesign -d -r-` zeigte ausschließlich CDHash-Anforderungen; `security find-identity -v -p codesigning` fand keine gültige Signieridentität. Nach neuem Code kann deshalb die Datenschutzentscheidung nicht zur neuen Anforderung passen. [Apple TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements) beschreibt diesen Unterschied ausdrücklich.

Bei offener Berechtigung wird der Central Manager nun erst durch **Drucker suchen** angelegt. Bereits erlaubte Installationen behalten die automatische Wiederverbindung. Abgelehnter Zugriff erhält einen konkreten Hinweis. Es wurden keine TCC-Einträge gelöscht oder Rechte automatisch erteilt. Das Build-Script unterstützt eine vorhandene feste Signieridentität über `LABEL_HELPER_CODE_SIGN_IDENTITY`; ohne Zertifikat bleiben bei neuen Entwicklungsbuilds erneute Freigaben möglich. Das zusätzliche Design-Prüffenster ist geschlossen.

## Ergebnis der Umsetzung und Nachprüfung

- Proportionen, Gruppierung, Aufgabeauswahl und typografische Hierarchie überarbeitet; lange Untertitel nach sichtbarer Trunkierung gekürzt.
- Weiter/Vorschau und Zurück liegen in der nativen Symbolleiste und sind über das Menü erreichbar. ⌘↩ wurde mit aktivem Textfeld geprüft; der Fokusrahmen und die Tab-Navigation sind sichtbar.
- Die Live-PDF-Vorschau verwendet `EtsyAddressLabelWriter.makePDFData` und erzeugt keine Druckaufträge, Dateien oder Briefmarkenreservierungen beim Tippen.
- Die dunkle native Oberfläche wurde in einem separaten Prüffenster bei 920 × 620 pt mit Musterdaten betrachtet. Das Brief-Layout wechselt dort untereinander; das breite Layout setzt Formular und Vorschau nebeneinander. Ein erster Offscreen-Render konnte native Vibrancy nicht korrekt abbilden und wurde nicht als Farbnachweis gewertet.
- Gemeinsame Papierdarstellung für Brief-, Briefmarken- und allgemeine Druckvorschau. Das Papier bleibt in beiden Erscheinungsmodi weiß.
- Universal-Build und Signaturprüfung bestanden. LabelCoreSelfTest mit SDK 26.5 bestanden: Navigation, Druckreihenfolge, Reservierungen, unklare Drucke und Wiederaufnahme.
- Grenzen: keine vollständige VoiceOver-Sitzung, kein physischer Druck und keine Prüfung auf einem zweiten Intel-Gerät. Reduce Motion benötigt keine Sonderanimation; eigene Transparenzschichten wurden vermieden. Erhöhter Kontrast und reduzierte Transparenz werden von den verwendeten Systemkomponenten übernommen, aber nicht separat im System umgeschaltet.

Bewertung nach der Überarbeitung: **Good**. Das spezifische Merkmal ist das eigene Papieretikett während der Vorbereitung. Eine weitere dekorative Oberfläche wurde bewusst nicht ergänzt; Navigation und echte Druckinhalte tragen die Gestaltung.

### Abschließende Prüfung der installierten App

Die installierte finale App wurde erneut geöffnet: native Liquid-Glass-Toolbar sichtbar, Kartentexte vollständig, „Importieren“ eindeutig beschriftet. Im breiten Fenster stehen die Adressfelder nun nachweislich neben der Vorschau. Die Startseite ist über ⇧⌘H erreichbar. Bei diesen Starts erschien keine unmittelbare Bluetooth-Abfrage. Die noch offene Freigabe wird beim bewussten Verbindungsversuch behandelt; eine neue Freigabe wurde während dieser Schlussprüfung nicht erteilt. Druckaufträge, Briefmarkenbestand und Briefverlauf sind bytegleich zum Ausgangsstand.
