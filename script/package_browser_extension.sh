#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/BrowserExtension"
DIST_DIR="$ROOT_DIR/dist"
ARCHIVE="$DIST_DIR/MunbynLabeler-Browser-Extension.zip"

node --test "$SOURCE_DIR/tests/etsy-order.test.js"
mkdir -p "$DIST_DIR"
rm -f "$ARCHIVE"
/usr/bin/ditto -c -k --norsrc --keepParent "$SOURCE_DIR" "$ARCHIVE"

echo "Browser-Erweiterung gepackt: $ARCHIVE"
