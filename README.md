# Munbyn Labeler

Native macOS app for sending 4 × 6 inch labels to a MUNBYN RW403B over Bluetooth.

The packaged app is a Universal 2 application containing native `arm64` and
`x86_64` binaries. It runs on Apple Silicon and Intel Macs with macOS 14 or
newer.

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
