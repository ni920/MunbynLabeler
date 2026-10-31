#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Label Helper"
# Retain the executable and bundle identity for existing preferences, print
# history, Bluetooth authorization and browser links when changing the name.
EXECUTABLE_NAME="MunbynLabeler"
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
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_BINARY="$APP_MACOS/$EXECUTABLE_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon-1024.png"
ICON_COMPOSER_SOURCE="$ROOT_DIR/Resources/AppIcon.icon"
UNIVERSAL_BUILD_DIR="$ROOT_DIR/.build-universal"

SWIFT_BUILD_ARGS=(
  --disable-sandbox
  -c "$CONFIGURATION"
  -debug-info-format none
  --product "$EXECUTABLE_NAME"
)

# Pass the SDK to SwiftPM and the linker explicitly. Cross-compiled builds
# otherwise advertised the deployment target (14.0) as the linked SDK and opted
# out of the modern appearance. Keep deployment target and build SDK separate.
SELECTED_SDK_PATH="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
SELECTED_SDK_PATH="$(cd "$SELECTED_SDK_PATH" && pwd -P)"
# The standalone macOS 27 CLT lacks SwiftUIMacros.StateMacro. The installed
# 26.5 SDK retains State's property wrapper and supports native Liquid Glass.
# Full Xcode installations keep their selected SDK and bundled macro plugins.
if [[ "$SELECTED_SDK_PATH" == /Library/Developer/CommandLineTools/SDKs/MacOSX27* &&
      -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]]; then
  SELECTED_SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
fi
export SDKROOT="$SELECTED_SDK_PATH"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.cache/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
mkdir -p "$CLANG_MODULE_CACHE_PATH"
SELECTED_SDK_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :Version' "$SELECTED_SDK_PATH/SDKSettings.plist")"
SWIFT_BUILD_ARGS+=(
  --sdk "$SELECTED_SDK_PATH"
  -Xlinker -platform_version
  -Xlinker macos
  -Xlinker "$MIN_SYSTEM_VERSION"
  -Xlinker "$SELECTED_SDK_VERSION"
)
# A stable Apple Development / Developer ID identity preserves privacy grants
# across builds. Without an installed identity, retain local ad-hoc signing.
SIGNING_IDENTITY="${LABEL_HELPER_CODE_SIGN_IDENTITY:--}"
echo "Build SDK: $SELECTED_SDK_PATH; minimum macOS: $MIN_SYSTEM_VERSION"

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Missing app icon source: $ICON_SOURCE" >&2
  exit 1
fi

pkill -x "$EXECUTABLE_NAME" >/dev/null 2>&1 || true

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
  BUILD_BINARIES+=("$BIN_PATH/$EXECUTABLE_NAME")
done

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$APP_FRAMEWORKS"
/usr/bin/lipo -create "${BUILD_BINARIES[@]}" -output "$APP_BINARY"
chmod +x "$APP_BINARY"
/usr/bin/install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BINARY"

SPARKLE_FRAMEWORK=""
for CANDIDATE in \
  "$UNIVERSAL_BUILD_DIR/arm64/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" \
  "$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"; do
  if [[ -d "$CANDIDATE" ]]; then
    SPARKLE_FRAMEWORK="$CANDIDATE"
    break
  fi
done

if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  echo "Sparkle.framework was not produced by Swift Package Manager." >&2
  exit 1
fi

/usr/bin/ditto "$SPARKLE_FRAMEWORK" "$APP_FRAMEWORKS/Sparkle.framework"

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

# Xcode's asset compiler embeds the real layered icon for macOS 26+, while
# CFBundleIconFile retains the ICNS fallback for older systems / CLT-only builds.
if [[ -d "$ICON_COMPOSER_SOURCE" ]]; then
  ASSET_COMPILER="$(/usr/bin/xcrun --find actool 2>/dev/null || true)"
  if [[ -n "$ASSET_COMPILER" && "${SELECTED_SDK_VERSION%%.*}" -ge 26 ]]; then
    # Compile optional layered assets separately. A format/renderer mismatch
    # must never leave a partial Assets.car in the distributable app bundle.
    ICON_COMPOSER_BUILD_DIR="$UNIVERSAL_BUILD_DIR/CompiledAppIcon"
    rm -rf "$ICON_COMPOSER_BUILD_DIR"
    mkdir -p "$ICON_COMPOSER_BUILD_DIR"
    if "$ASSET_COMPILER" "$ICON_COMPOSER_SOURCE" \
      --compile "$ICON_COMPOSER_BUILD_DIR" \
      --platform macosx --target-device mac \
      --minimum-deployment-target "$MIN_SYSTEM_VERSION" \
      --app-icon AppIcon \
      --output-partial-info-plist "$UNIVERSAL_BUILD_DIR/icon-info.plist" \
      --output-format human-readable-text && \
      [[ -f "$ICON_COMPOSER_BUILD_DIR/Assets.car" ]]; then
      /usr/bin/ditto "$ICON_COMPOSER_BUILD_DIR/Assets.car" "$APP_RESOURCES/Assets.car"
      echo "Layered Icon Composer asset compiled."
    else
      echo "Layered icon export unavailable; using the verified compatible ICNS icon." >&2
    fi
  else
    echo "Modern actool unavailable: using the compatible ICNS icon; layered source retained."
  fi
fi


cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMultipleInstancesProhibited</key>
  <true/>
  <key>CFBundleShortVersionString</key>
  <string>0.8.0</string>
  <key>CFBundleVersion</key>
  <string>21</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSBluetoothAlwaysUsageDescription</key>
  <string>Label Helper verbindet sich mit deinem RW403B und überträgt Etiketten zum Drucken.</string>
  <key>NSBluetoothPeripheralUsageDescription</key>
  <string>Label Helper benötigt Bluetooth für die Verbindung zum RW403B.</string>
  <key>SUFeedURL</key>
  <string>https://github.com/ni920/MunbynLabeler/releases/latest/download/appcast.xml</string>
  <key>SUPublicEDKey</key>
  <string>4aN2cdQ63ff/1pUEqYsGAJEvzMI126W3mlxwUCvIhCY=</string>
  <key>SUEnableAutomaticChecks</key>
  <true/>
  <key>SUAutomaticallyUpdate</key>
  <true/>
  <key>SUVerifyUpdateBeforeExtraction</key>
  <true/>
  <key>SURequireSignedFeed</key>
  <true/>
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

# Check the actual Mach-O metadata; successful compilation alone doesn't
# establish which system appearance macOS will select for the final bundle.
/usr/bin/vtool -show-build "$APP_BINARY" | /usr/bin/awk \
  -v sdk="$SELECTED_SDK_VERSION" -v minimum="$MIN_SYSTEM_VERSION" \
  -v architectures="${#TARGET_ARCHITECTURES[@]}" '
  $1 == "sdk" { sdk_count++; if ($2 != sdk) invalid = 1 }
  $1 == "minos" { minimum_count++; if ($2 != minimum) invalid = 1 }
  END {
    if (invalid || sdk_count != architectures || minimum_count != architectures) {
      print "Unexpected SDK or deployment metadata in the Universal app" > "/dev/stderr"
      exit 1
    }
  }'

/usr/bin/codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_FRAMEWORKS/Sparkle.framework"
/usr/bin/codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"

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
    /usr/bin/log stream --info --style compact --predicate "process == \"$EXECUTABLE_NAME\""
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
    pgrep -x "$EXECUTABLE_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [build|run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
