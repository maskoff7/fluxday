# Fluxday

**Your money, mapped day by day.** Fluxday is a private, local-first cash-flow planner built natively for macOS with SwiftUI and Swift Charts. It shows when a future balance becomes tight, which payments caused it, and how recurring-operation scenarios change the result.

![Fluxday balance forecast and cash-gap outlook](docs/screenshots/native-planner.png)

## Highlights

- Exact daily forecasts using integer minor-unit arithmetic.
- Certain vs expected operations and a “without expected income” stress view.
- Monday-first financial calendar and recurring series with anchored month-end behavior.
- Week, month, year, and custom-period summaries with drill-down charts.
- Base vs Scenario comparisons that never mutate the base plan.
- Native menus, keyboard navigation, Undo/Redo, accessibility, Light/Dark Mode, and resizable layouts.
- English interface with complete Russian localization.
- SQLite autosave, portable backups, and safe migration from Fluxday v0.1.0.
- Offline by design: no accounts, backend, telemetry, or network calls.

![Fluxday operations](docs/screenshots/native-operations.png)

![Fluxday financial calendar](docs/screenshots/native-calendar.png)

![Fluxday scenario comparison](docs/screenshots/native-scenarios.png)

## Install

Fluxday v0.2.0 requires macOS 14 or later. Download the `.dmg` or `.zip` from the [latest release](https://github.com/maskoff7/fluxday/releases/latest), then move Fluxday to Applications.

The current development build is unsigned because Apple Developer credentials are not available yet. macOS may require Control-clicking Fluxday in Finder and choosing **Open** on first launch. Signing and notarization are tracked in [issue #6](https://github.com/maskoff7/fluxday/issues/6).

## Build and test

Xcode 16 or later is required.

```sh
swift test --package-path native/CashFlowCore
swift test --package-path native/FluxdayPersistence
xcodebuild \
  -project native/Fluxday.xcodeproj \
  -scheme Fluxday \
  -configuration Debug \
  -derivedDataPath native/.build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Open `native/Fluxday.xcodeproj` in Xcode to run and debug the application.

## Data and backups

Fluxday automatically stores its plan in `~/Library/Application Support/app.fluxday.desktop/fluxday-native.sqlite3`.

On first launch, the native app detects the v0.1.0 database in the same application-support folder, shows a migration preview, and copies validated data into the new database without modifying the original. **Create Backup…** and **Restore from Backup…** use the versioned portable JSON format for manual transfer and recovery.

## Architecture and documentation

- [Architecture](docs/architecture.md)
- [Financial algorithms](docs/financial-algorithms.md)
- [Data model](docs/data-model.md)
- [Native storage and v0.1.0 migration](docs/native-data-migration.md)
- [Testing](docs/testing.md)
- [v0.2.0 release notes](docs/release-v0.2.0.md)
- [Development guide](CONTRIBUTING.md)

The Tauri/React/Rust v0.1.0 source is preserved at the immutable [`v0.1.0` tag](https://github.com/maskoff7/fluxday/releases/tag/v0.1.0) and under `reference/legacy/tauri-v0.1.0/`. No license has been selected.
