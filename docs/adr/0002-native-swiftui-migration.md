# ADR 0002: Replace the production shell with native SwiftUI

- Status: Accepted
- Date: 2026-09-05
- Supersedes: the production-target portion of ADR 0001 after native parity

## Context

Fluxday v0.1.0 proved the cash-flow model and product workflows with Tauri, React, TypeScript, Rust and SQLite. The next product strategy prioritizes a first-class macOS experience and later reuse of financial logic on iOS. The released v0.1.0 must remain usable and its data must migrate without re-entry.

## Decision

Fluxday v0.2.0 will be a native macOS application built with Swift, SwiftUI, Swift Charts and focused AppKit bridges only where SwiftUI lacks required behavior. A pure Swift package named `CashFlowCore` owns deterministic financial rules and has no UI or persistence dependency. An actor-isolated persistence layer uses the system SQLite C API without an ORM.

The native application uses bundle identifier `app.fluxday.desktop` and a new database filename. On first launch it looks for the v0.1.0 `fluxday.sqlite3`, reads its JSON snapshot without modifying it, validates it through `CashFlowCore`, and offers migration. Portable Fluxday JSON remains supported.

User-facing localization uses Apple String Catalogs. English is the development and fallback language; Russian is complete and selectable alongside System Default.

## Consequences

Benefits:

- native controls, menus, windows, charts, accessibility and platform behavior;
- no WebView or JavaScript runtime in the production application;
- reusable financial logic for a later iOS application;
- no third-party database, chart or localization dependency;
- explicit compatibility boundary around the proven v0.1.0 format.

Costs:

- macOS and Windows no longer share presentation code;
- parity must be maintained temporarily across two implementations;
- the Xcode/macOS build requires macOS CI runners;
- migration and golden compatibility tests become release-critical.

## Rejected alternatives

- Keep Tauri and restyle it: does not deliver native controls or remove the WebView runtime.
- Embed the existing web interface: preserves the exact limitation the migration is intended to remove.
- Introduce a cross-platform Swift/C++ core now: adds complexity without helping the current macOS or planned iOS targets.
- Add a Swift SQLite ORM: unnecessary for the small atomic local snapshot model and complicates migrations.
