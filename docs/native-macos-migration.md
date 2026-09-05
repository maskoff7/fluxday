# Native macOS migration plan

Fluxday v0.1.0 remains the released Tauri reference until the native application reaches verified feature and data parity. Native work lives beside it under `native/`; the web/Tauri production tree is removed only in the final v0.2.0 release pull request.

## Compatibility contract

The native app preserves these v0.1.0 semantics:

- money is exact integer minor units;
- financial dates are validated Gregorian calendar dates, never timestamps;
- monthly recurrence remains anchored to the original day, including month-end clamping;
- yearly leap-day recurrence maps to February 28 in non-leap years;
- the primary cash-gap metric uses the closing balance after every operation in a day;
- the stress balance removes expected income only and retains every expense;
- scenarios store sparse overrides and never mutate base operations;
- summaries aggregate actual occurrences by source operation;
- JSON export/import preserves settings, operations, recurring series, certainty and scenarios.

The v0.1.0 SQLite database contains a single `app_state` row whose `payload` is the portable JSON snapshot. The native app will read this database as an untrusted migration source, validate and decode the snapshot, preview the result, then atomically store it in a separate native database. The original database is left untouched so migration is recoverable.

## Native structure

```text
native/
├── CashFlowCore/       Pure reusable Swift package
├── Fluxday/            SwiftUI application and feature views
├── FluxdayPersistence/ SQLite actor and migration boundary
├── FluxdayTests/       App, persistence and migration tests
└── Fluxday.xcodeproj/  macOS application project
```

`CashFlowCore` depends only on the Swift standard library and Foundation calendar primitives. It contains models, validation, recurrence, forecasts, gap detection, stress calculations, scenarios, analytics and portable JSON contracts. It must not import SwiftUI, Charts, AppKit or SQLite.

The application uses `NavigationSplitView`, native toolbars, sheets, Settings, menus, commands, UndoManager, Swift Charts and system appearance. Synchronous SQLite work is isolated in an actor; views receive immutable calculation results on the main actor.

## Delivery sequence

1. Add the native Xcode project, English fallback localization, Russian String Catalog entries and macOS CI while keeping v0.1.0 buildable.
2. Port deterministic financial behavior to `CashFlowCore` with golden compatibility vectors.
3. Add the native SQLite store, schema migrations, automatic v0.1.0 discovery and portable JSON import/export.
4. Build operations, timeline, balance chart and cash-gap workflows.
5. Add the financial calendar and recurring-series management.
6. Add summaries, drill-down charts and Base vs Scenario comparison.
7. Complete localization, native commands, undo, accessibility, resize/performance QA and English screenshots.
8. Verify parity, archive the Tauri source under `reference/legacy/tauri-v0.1.0/`, switch production CI/builds to native and publish v0.2.0.

## Release gates

Every implementation pull request must pass Swift unit tests and a code-signing-disabled macOS build. UI pull requests include English screenshots from a running native app. The final release additionally verifies restart persistence, v0.1.0 automatic migration, JSON round trips, both localizations, empty/large/negative datasets and an unsigned DMG artifact when signing credentials are unavailable.

Future iOS reuse is achieved through the pure Swift core and portable specifications. No cross-platform UI abstraction, Windows or Android code is introduced during v0.2.0.
