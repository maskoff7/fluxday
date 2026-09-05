# Fluxday

**Your money, mapped day by day.** Fluxday is a private, local-first cash-flow planner for macOS. It shows when a future balance becomes tight, which payments caused it and how recurring-operation scenarios change the result.

> `v0.1.0` is the released Tauri implementation. Development of the fully native SwiftUI `v0.2.0` is tracked in [issue #13](https://github.com/maskoff7/fluxday/issues/13) and follows the [native migration plan](docs/native-macos-migration.md). The released application remains supported until native feature and data parity is verified.

![Native Fluxday balance forecast and cash-gap outlook](docs/screenshots/native-planner.png)

## Highlights

- Daily timeline, balance chart, Monday-first financial calendar and recurring-series management.
- Certain vs expected operations and an explicit “without expected income” stress test.
- Week, month, year and custom-period analytics with operation drill-down.
- Sparse Base vs Scenario overrides that never mutate the base plan.
- Integer minor-unit arithmetic and calendar-date recurrence without timezone drift.
- SQLite autosave, JSON import preview, export, backup and legacy Cash Flow Planner compatibility.
- Offline by design: no accounts, backend, telemetry or network calls.

## Requirements

- macOS 12 or newer for the tested desktop experience.
- Node.js 24+, npm 11+ and Rust 1.95+ for development.
- Xcode Command Line Tools and the standard [Tauri macOS prerequisites](https://v2.tauri.app/start/prerequisites/).

## Development

```bash
npm install
npm run tauri dev
```

The browser-only UI is available with `npm run dev`; it uses local storage instead of SQLite and is intended for frontend development.

## Quality checks

```bash
npm run format:check
npm run lint
npm run typecheck
npm test
cargo test --manifest-path src-tauri/Cargo.toml
npm run build
npm run tauri build -- --bundles app
```

## Data and backups

Production data is stored in `fluxday.sqlite3` under the operating system's application-data directory. Export and backup create portable JSON; import always shows a preview and replaces the current plan only after confirmation. Legacy browser exports from `cashflow_planner.html` are supported.

## Documentation

- [Architecture](docs/architecture.md)
- [Data model](docs/data-model.md)
- [Legacy audit](docs/legacy-audit.md)
- [Brand](docs/brand.md)
- [Testing](docs/testing.md)
- [Financial algorithms](docs/financial-algorithms.md)
- [Native data storage and migration](docs/native-data-migration.md)
- [Product backlog](docs/product-backlog.md)
- [v0.1.0 release notes](docs/release-v0.1.0.md)
- [Native macOS migration plan](docs/native-macos-migration.md)
- [Development and contributions](CONTRIBUTING.md)

The original prototype is preserved in `reference/legacy/`. No license has been selected.
