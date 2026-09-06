# Fluxday 0.2.0 — Native macOS

Fluxday 0.2.0 replaces the Tauri/WebView application with a fully native macOS experience built in Swift, SwiftUI, and Swift Charts.

## What is new

- Native macOS navigation, toolbar, Settings, sheets, menus, keyboard shortcuts, Undo/Redo, accessibility, and system appearance.
- Exact `CashFlowCore` financial engine for money, calendar dates, recurrence, forecasts, cash gaps, stress mode, scenarios, and summaries.
- Native balance, composition, and scenario charts with hover and selection details.
- Operations, timeline, financial calendar, recurring-series management, analytics, and scenario comparison at v0.1.0 feature parity.
- Complete English interface and Russian localization using an Apple String Catalog.
- Local SQLite autosave with background I/O and persistence across launches.
- Safe first-run migration from v0.1.0 that leaves the original database unchanged.
- **Create Backup…** and **Restore from Backup…** for versioned portable JSON transfer and recovery.

## Compatibility

- Requires macOS 14 or later.
- Preserves v0.1.0 money, recurrence, forecast, scenario, and JSON semantics.
- Automatically detects a v0.1.0 SQLite database in Fluxday’s application-support folder and shows a migration preview.

## Installation

Download either release asset and move Fluxday to Applications:

- `Fluxday-v0.2.0-macOS.dmg`
- `Fluxday-v0.2.0-macOS.zip`

These are unsigned universal development builds for Apple Silicon and Intel Macs. Until signing and notarization are available, macOS may require Control-clicking Fluxday in Finder and choosing **Open** on first launch. Checksums are provided in `SHA256SUMS.txt`.

Fluxday remains offline and local-first with no account, backend, telemetry, or network access.
