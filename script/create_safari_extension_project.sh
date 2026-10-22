#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/BrowserExtension"
OUTPUT_DIR="$ROOT_DIR/SafariExtension"

PACKAGER="$(xcrun --find safari-web-extension-packager 2>/dev/null || true)"
if [[ -z "$PACKAGER" ]]; then
  PACKAGER="$(xcrun --find safari-web-extension-converter 2>/dev/null || true)"
fi
if [[ -z "$PACKAGER" ]]; then
  echo "Safari Web Extension Packager wurde nicht gefunden. Bitte zuerst Xcode installieren." >&2
  exit 1
fi

if [[ -e "$OUTPUT_DIR" ]]; then
  echo "Zielordner existiert bereits: $OUTPUT_DIR" >&2
  exit 1
fi

"$PACKAGER" "$SOURCE_DIR" \
  --project-location "$OUTPUT_DIR" \
  --app-name "Munbyn Labeler für Etsy" \
  --bundle-identifier "de.nicosaia.MunbynLabeler.EtsyExtension" \
  --swift \
  --macos-only \
  --copy-resources \
  --no-prompt \
  --no-open

echo "Safari-Projekt erstellt: $OUTPUT_DIR"
