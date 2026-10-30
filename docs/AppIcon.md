# Label Helper App-Icon

Das Motiv ist ein Versandetikett mit einer abziehbaren Ecke und drei kräftigen Adresszeilen. Es enthält weder Schrift noch ein Bluetooth-Zeichen oder ein gerätespezifisches Druckerbild. Die Konturen bleiben bei 16–64 Pixeln erkennbar.

## Dateien

- `Resources/AppIcon.icon`: mehrschichtiges, bearbeitbares Icon-Composer-Paket.
- `Resources/IconArtwork`: ursprüngliche SVG-Ebenen, erzeugtes Icon-Dokument und kompatibles PNG.
- `Resources/AppIcon-1024.png`: aktuell eingebautes statisches Quellbild.
- `Resources/IconPreviews`: eigene kompatible Vorschauen in Default, Dark und Mono sowie kleinen Größen.
- `script/create_icon_artwork.swift`: reproduzierbare Originalgrafik. Die SVG-Ebenen und der kompatible PNG-Renderer verwenden dieselben Pfade.

Die `.icon`-Ebenen bleiben unmaskiert, ohne eingebrannte Schatten, Glanz oder Unschärfe. Das Paket konfiguriert Materialeigenschaften und Farben; Icon Composer kann die Systemeffekte daraus erzeugen. Der kompatible ICNS-Renderer verwendet eine statische macOS-Grundform und einen zurückhaltenden Papierschatten. Seine PNGs sind keine Exporte des Apple-Renderers.

## Verwendeter Skill

[compose-app-icon von giginet](https://github.com/giginet/apple-icon-composer-skill/tree/43b96bf200e088149abef29a1b999c70589bed81/plugins/icon-composer/skills/compose-app-icon), festgehalten auf Commit `43b96bf200e088149abef29a1b999c70589bed81`.

Der Skill samt Skripten wurde in einem separaten temporären Ordner gelesen und geprüft. `uv` war vorhanden. Die Abhängigkeiten wurden mit `uv sync --frozen --no-dev` eingerichtet; `create_icon.py` hat das Paket aus dem Dokument und den drei SVGs erstellt. `validate_icon.py` meldet:

```
VALID: Resources/AppIcon.icon/icon.json
```

Die Prüfung umfasst JSON Schema Draft 2020-12 und sämtliche Asset-Verweise. Keine fehlenden oder ungenutzten Assets. Es werden ausschließlich 1.x-kompatible Schlüssel verwendet, die auch das 2.x-Schema akzeptiert; kein unbekannter Feature-Gate und keine unvollständige Positionsangabe.

## Build und Prüfgrenzen

Der lokale Universal-Build verwendet den statischen ICNS-Fallback. Die elf ICNS-Einträge wurden vollständig geparst und auf PNG-Signatur, Dateilänge und Maße von 16–1024 Pixeln geprüft. Intel-/Apple-Silicon-Architekturen und Bundle-Signatur sind gültig. Das aktuelle App-Bundle und die frühere Icon-Quelle sind gesichert.

Wenn Xcodes `actool` und ein SDK ab macOS 26 verfügbar sind, versucht der Build das Paket zusätzlich zu `Assets.car` zu kompilieren. Auf dem GitHub-Runner hat Xcode 26.3 den Export mit „The data couldn’t be read because it isn’t in the correct format“ abgelehnt. Das Release verwendet in diesem Fall das geprüfte kompatible ICNS-Icon. Der Export läuft in einem separaten Ordner; fehlgeschlagene oder unvollständige native Assets gelangen nicht ins App-Bundle.

Lokal sind Icon Composer, `ictool` und `actool` nicht installiert. Apples Download führt zur Apple-ID-Anmeldung. Die native Materialdarstellung ist deshalb weiterhin offen; Schema-Validierung allein beweist keine Kompatibilität mit Apples Renderer. Es wurde keine Anmeldung vorgenommen.

Die App verwendet weiterhin den Bundle-Identifier `de.nicosaia.MunbynLabeler`, damit Einstellungen und Druckverlauf erhalten bleiben. Das kompatible Icon ist lokal eingebaut; die dynamischen Materialeffekte des Apple-Renderers wurden hier mangels Icon Composer nicht visuell geprüft.
