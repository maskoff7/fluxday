# Testing strategy

`npm test` covers calendar validation, anchored recurrence, leap years, long ranges, daily cash flow, closing-balance gap detection, stress mode, scenario immutability, summaries and legacy import. `cargo test` exercises schema migration idempotency and atomic snapshot replacement.

`npm run lint`, `npm run typecheck`, `npm run format:check` and `npm run build` are required before a release. `npm run tauri build -- --bundles app` verifies the native macOS bundle. UI smoke checks cover first-run import, empty and sample states, operation CRUD/undo, each primary view, narrow/normal/fullscreen layouts, long names, negative balances and large money values.
