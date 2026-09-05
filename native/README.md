# Fluxday for macOS

This directory contains the fully native Fluxday application that will replace the Tauri implementation in v0.2.0 after feature and data parity is verified.

## Requirements

- macOS 14 or later
- Xcode 16 or later

## Build

```sh
xcodebuild \
  -project native/Fluxday.xcodeproj \
  -scheme Fluxday \
  -configuration Debug \
  -derivedDataPath native/.build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The v0.1.0 Tauri application remains buildable from the repository root during the migration.

## Bootstrap preview

![Native Fluxday application shell in English](../docs/screenshots/native-bootstrap.png)
