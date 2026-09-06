# Architecture

Fluxday v0.2.0 is a fully native macOS application built with Swift, SwiftUI, Swift Charts, AppKit where required, and SQLite. It is local-first and has no account, backend, telemetry, or network dependency.

```text
SwiftUI / AppKit application
            ↓
      application model
       ↙           ↘
CashFlowCore    FluxdayPersistence
pure Swift      SQLite actor + migration
```

## CashFlowCore

`native/CashFlowCore` owns exact money, validated Gregorian dates, operations, recurrence, forecasts, cash-gap detection, stress calculations, scenarios, summaries, and portable JSON contracts. It depends on Foundation calendar primitives but not SwiftUI, AppKit, Charts, or SQLite. This boundary keeps financial behavior deterministic and reusable for a future iOS application.

## Persistence

`native/FluxdayPersistence` serializes validated plan snapshots into a single-row SQLite store. An actor isolates database I/O from the main thread, schema setup is transactional, and every save atomically replaces the current snapshot. Backup restore and v0.1.0 migration pass through the same decoder and plan validator before storage.

The native database is separate from the v0.1.0 database. Migration reads the legacy snapshot without writing to its source, presents a preview, and copies the complete plan only after confirmation.

## Application

`native/Fluxday` owns presentation state and native macOS behavior. It uses `NavigationSplitView`, system toolbars and sheets, a Settings scene, native commands and UndoManager, Swift Charts, Swift Concurrency, Dynamic Type-aware layouts, VoiceOver summaries, and system Light/Dark Mode.

The application model publishes immutable calculation results to views on the main actor. Forecast calculations run in cancellable tasks, while SQLite and import work stay off the UI thread.

The historical Tauri implementation is archived under `reference/legacy/tauri-v0.1.0/` and at the immutable `v0.1.0` tag; it is not part of the v0.2.0 production build.
