# Label Helper Etsy-Erweiterung

Die Erweiterung ergänzt Etsy-Bestellseiten um **An Label Helper senden**.
Sie liest die aktuell geöffnete Bestellung erst nach einem Klick und öffnet die
lokal installierte Label-Helper-App. Es werden keine Bestelldaten an einen
Server übertragen.

## Chrome installieren

1. Das Erweiterungs-ZIP entpacken.
2. `chrome://extensions` öffnen.
3. **Entwicklermodus** einschalten.
4. **Entpackte Erweiterung laden** wählen und den Ordner `BrowserExtension`
   auswählen.
5. Eine Etsy-Bestellung mit sichtbarer Versandadresse öffnen.

## Safari lokal installieren

Aktuelle Safari-Versionen können den entpackten Erweiterungsordner über den
Developer-Tab vorübergehend laden. Für eine dauerhaft installierbare lokale
Version verpackt Safari WebExtensions in einer kleinen macOS-Container-App.
Mit installiertem Xcode kann dafür ein Projekt erzeugt werden:

```bash
./script/create_safari_extension_project.sh
```

Anschließend das erzeugte Xcode-Projekt bauen, die Erweiterung unter
**Safari → Einstellungen → Erweiterungen** aktivieren und Etsy den Zugriff
erlauben. Für eine regulär signierte Weitergabe der Safari-Erweiterung ist eine
Apple-Developer-Mitgliedschaft erforderlich.

## Verwendung

1. Etsy-Shop-Manager öffnen und eine Bestellung mit Versandadresse anzeigen.
2. **An Label Helper senden** anklicken.
3. Den Browserdialog zum Öffnen von Label Helper bestätigen.
4. In der App **Brief** oder **Paket** wählen und die Daten prüfen.
