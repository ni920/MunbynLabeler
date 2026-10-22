#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="MunbynLabeler"
BUNDLE_ID="de.nicosaia.MunbynLabeler"
MIN_SYSTEM_VERSION="14.0"
CONFIGURATION="release"
TARGET_ARCHITECTURES=(arm64 x86_64)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon-1024.png"
UNIVERSAL_BUILD_DIR="$ROOT_DIR/.build-universal"

SWIFT_BUILD_ARGS=(
  --disable-sandbox
  -c "$CONFIGURATION"
  -debug-info-format none
  --product "$APP_NAME"
)

# The currently installed standalone Command Line Tools expose a newer compiler
# patch than their default macOS 27 SDK and do not ship SwiftUI's macro plugin.
# Use the compatible macOS 15.2 SDK only for that CLT-only configuration.
if [[ ! -d "/Applications/Xcode.app" && -d "/Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk" ]]; then
  export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk"
  export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.cache/clang-15"
  export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
  mkdir -p "$CLANG_MODULE_CACHE_PATH"
  SWIFT_BUILD_ARGS+=(
    -Xswiftc -Xfrontend
    -Xswiftc -interface-compiler-version
    -Xswiftc -Xfrontend
    -Xswiftc 6.0
  )
fi

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Missing app icon source: $ICON_SOURCE" >&2
  exit 1
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

cd "$ROOT_DIR"

BUILD_BINARIES=()
for ARCHITECTURE in "${TARGET_ARCHITECTURES[@]}"; do
  SCRATCH_PATH="$UNIVERSAL_BUILD_DIR/$ARCHITECTURE"
  TARGET_TRIPLE="$ARCHITECTURE-apple-macosx$MIN_SYSTEM_VERSION"

  echo "Building $APP_NAME for $ARCHITECTURE..."
  swift build \
    "${SWIFT_BUILD_ARGS[@]}" \
    --scratch-path "$SCRATCH_PATH" \
    --triple "$TARGET_TRIPLE"

  BIN_PATH="$(swift build \
    "${SWIFT_BUILD_ARGS[@]}" \
    --scratch-path "$SCRATCH_PATH" \
    --triple "$TARGET_TRIPLE" \
    --show-bin-path)"
  BUILD_BINARIES+=("$BIN_PATH/$APP_NAME")
done

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
/usr/bin/lipo -create "${BUILD_BINARIES[@]}" -output "$APP_BINARY"
chmod +x "$APP_BINARY"

ICONSET_DIR="$UNIVERSAL_BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

create_icon_size() {
  local pixels="$1"
  local filename="$2"
  /usr/bin/sips -z "$pixels" "$pixels" "$ICON_SOURCE" --out "$ICONSET_DIR/$filename" >/dev/null
}

create_icon_size 16 icon_16x16.png
create_icon_size 32 icon_16x16@2x.png
create_icon_size 32 icon_32x32.png
create_icon_size 64 icon_32x32@2x.png
create_icon_size 128 icon_128x128.png
create_icon_size 256 icon_128x128@2x.png
create_icon_size 256 icon_256x256.png
create_icon_size 512 icon_256x256@2x.png
create_icon_size 512 icon_512x512.png
create_icon_size 1024 icon_512x512@2x.png
/usr/bin/swift "$ROOT_DIR/script/create_icns.swift" "$ICONSET_DIR" "$APP_RESOURCES/AppIcon.icns"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>Munbyn Labeler</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.5.5</string>
  <key>CFBundleVersion</key>
  <string>11</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSBluetoothAlwaysUsageDescription</key>
  <string>Munbyn Labeler verbindet sich mit deinem RW403B und überträgt Etiketten zum Drucken.</string>
  <key>NSBluetoothPeripheralUsageDescription</key>
  <string>Munbyn Labeler benötigt Bluetooth für die Verbindung zum RW403B.</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>de.nicosaia.MunbynLabeler.etsy-order</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>munbyn-labeler</string>
      </array>
    </dict>
  </array>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  build)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    /usr/bin/lipo "$APP_BINARY" -verify_arch arm64
    /usr/bin/lipo "$APP_BINARY" -verify_arch x86_64
    /usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [build|run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
