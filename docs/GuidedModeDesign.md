# Geführter Versand in Label Helper

> Die folgende Datei dokumentiert die erste Assistenten-Version. Die spätere
> macOS-Designprüfung und die aktuelle Gestaltung stehen in [AppleDesignReview.md](AppleDesignReview.md).

Die Hauptansicht beantwortet zuerst „Was möchtest du machen?“. Brief, fertiges Paketlabel und Briefmarken sind drei gleichwertige Aufgaben. Der Direktmodus bleibt für wiederholte Arbeiten verfügbar. Der Wechsel wird gespeichert; laufende Druckabläufe bleiben davon unabhängig.

## Befund und Entscheidung

- `DashboardView.swift` zeigte eine große Überschrift, eine große Verbindungskarte und anschließend das gesamte Versandformular. Die neue Startseite ersetzt diesen Einstieg durch drei beschriftete Aufgaben. Die Verbindung bleibt über einen gemeinsamen Toolbar-Button erreichbar.
- `ShippingFormView.swift` zeigte Adresse, Absender, Papier und Frankierung gleichzeitig. Im geführten Modus erscheinen diese Entscheidungen nacheinander; Zurück erhält die Eingaben.
- `LabelFormatControls.swift` versteckte Picker-Beschriftungen und zeigte ständig Rastermaße. Sichtbare Bezeichnungen und aufklappbare technische Angaben helfen bei der Auswahl.
- `SettingsView.swift` stellte Druckgeschwindigkeit vor den Absender. Bedienmodus und Absender stehen jetzt zuerst, technische Werte unter „Erweiterte Druckeinstellungen“.
- Die Druckvorschau und die abgesicherten Briefabläufe bleiben die abschließende Prüfung. Ein Weiter-Button druckt keine Marke automatisch.

## HIG-Grundlage

Gelesene lokale Apple-HIG-Referenzen unter `apple-design/references/hig/`: accessibility, layout, typography, color, designing-for-macos, entering-data, settings, sidebars, modality, writing und buttons.

- Layout / Visual hierarchy: “Use progressive disclosure to make layouts cleaner and easier to interact with.”
- Entering data: “When possible, offer choices instead of requiring text entry.”
- Writing / Best practices: “Give clear guidance and use consistent language throughout processes with multiple steps.”
- Typography / Using system fonts: “Consider using the built-in text styles.”
- Accessibility / Vision: “Prefer system-defined colors.”

## Aufbau

```
Regulär                             Kompakt (ab 920 × 620)
Sidebar | Geführt / Direkt | Drucker Sidebar | Modus | Drucker
        | Was möchtest du machen?          | Was möchtest du machen?
        | Brief                             | Brief
        | Paketlabel                        | Paketlabel
        | Briefmarken                       | Briefmarken

        | Brief · Schritt 1 von 4           | Brief · Schritt 1 von 4
        | Empfänger                         | Empfänger
        | Formular, scrollbar               | Formular, scrollbar
        | Zurück        Weiter: Frankierung | Zurück        Weiter
```

Die Aufgaben bleiben als breite Zeilen auch im kleinen Fenster gut lesbar. Ein fester Fußbereich enthält Navigation und konkrete Hinweise zu fehlenden Angaben. Kein horizontaler Inhaltsscroll und keine verschachtelten Assistentenfenster.

## Gestaltung und Zugänglichkeit

Native macOS-Schriften: title (22 pt), title2 (17 pt), headline/body (13 pt). Wesentliche Anweisungen verwenden die primäre Textfarbe. Systemhintergrund, labelColor, secondaryLabelColor und accentColor passen sich Hell/Dunkel sowie Kontrast-Einstellungen an; keine nachgebauten Systemfarben. Farbe ist nie der einzige Statushinweis. Buttons haben mindestens reguläre macOS-Controlgröße, Aufgaben volle Zeilenhöhe. Native Buttons, Picker, Textfelder und Beschriftungen unterstützen Tastatur und VoiceOver. macOS hat kein iOS-Dynamic-Type; variable Fensterbreite und scrollende Inhalte erhalten die Lesbarkeit.

Referenzmessung mit AppKit in sRGB (normale Aqua-/Dark-Aqua-Erscheinung, Alpha über windowBackgroundColor verrechnet; diese Werte werden **nicht** fest im Code hinterlegt):

| Rolle | Hell | Dunkel | Kontrast gegen Fläche hell / dunkel |
| --- | --- | --- | --- |
| Fläche (`windowBackgroundColor`) | #FFFFFF | #1E1E1E | Referenzfläche |
| Inhalt (`labelColor`) | #272727 | #DDDDDD | 14,94:1 / 12,23:1 |
| Zusatz (`secondaryLabelColor`) | #808080 | #9A9A9A | 3,95:1 / 5,89:1 |
| Akzent (`controlAccentColor`) | #007AFF | #007AFF | 4,02:1 / 4,15:1 |

Die neuen Schrittanweisungen und Validierungshinweise verwenden primären Inhalt, da sekundäre Schrift in der hellen Referenzmessung 4,5:1 unterschreitet. Akzent dient nativen Controls, nicht kleinen frei gesetzten Anweisungen. Native Button-Inhalte und erhöhte Kontrast-Einstellungen werden vom System gezeichnet; diese Messung ist keine Screenshot-Kontrastbehauptung für sämtliche Zustände.

Keine Animation erforderlich. Keine Inhaltsunschärfe oder dekoratives Glas. Monospace bleibt Sendungsnummern vorbehalten. Eine primäre Weiter-/Vorschau-Aktion pro Schritt. Technische Daten sind aufklappbar. Verworfene Zutat: die bisherige Slogan-Überschrift samt großer Verbindungskarte.

## Prüfung

Core-Selbsttests prüfen Aufgabenwechsel, Schrittgrenzen, Rückwärtsnavigation und Import-Routing. Beide macOS-Architekturen werden gebaut. Die installierte App wird über ihre native Oberfläche geprüft; bezahlte Briefmarken werden dabei nur als Vorschau geöffnet.

### Lokal geprüft am 30.10.2026

- Universal-Build mit arm64 und x86_64 erfolgreich; beide Architekturen per `lipo` und Bundle-Signatur per `codesign --verify --deep --strict` geprüft.
- LabelCoreSelfTest einschließlich Navigation, Briefablauf, Bestandsreservierung und Druckwiederaufnahme erfolgreich.
- Installierte App: Startauswahl, fehlende Empfängerangaben, Zurück mit erhaltener Adresse, Frankierungswahl, gespeichertes Format, Rastervorschau, Geführt/Direkt, Settings und Tastaturbefehl zur Startseite geprüft.
- Echtes vorhandenes DHL-PDF importiert: Prüfschritt mit 100 × 150 mm und beibehaltenem Status „Gedruckt“. Keine erneute Ausgabe.
- Zehn vorhandene Briefmarken ausgewählt: ein Etikett in Originalgröße, abschließende Zusammenfassung erreicht.
- Neustart übernimmt die Modusauswahl. Testetikett nur als Vorschau erstellt und anschließend gezielt entfernt. Bestand und Briefverlauf sind bytegleich zum Ausgangszustand; kein physischer Druck ausgeführt.
- Die kompakte Aufteilung ist durch scrollbar begrenzten Inhalt und festen Fußbereich vorgesehen. Ein tatsächliches Verkleinern des Fensters ließ sich mit dem verfügbaren UI-Zugriff nicht verifizieren. Eine separate VoiceOver-Sitzung und erhöhte Kontrast-Einstellungen wurden nicht ausgeführt; die nativen Beschriftungen sind im Accessibility-Baum vorhanden.
