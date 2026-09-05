# Testing strategy

`npm test` covers calendar validation, anchored recurrence, leap years, long ranges, daily cash flow, closing-balance gap detection, stress mode, scenario immutability, summaries and legacy import. `cargo test` exercises schema migration idempotency and atomic snapshot replacement.

`swift test --package-path native/CashFlowCore` verifies the portable native financial contract with checked minor-unit arithmetic, strict Gregorian dates, recurrence anchors, forecasts, cash gaps, stress mode, scenarios, summaries and the v0.1.0 golden JSON fixture. During migration, these Swift tests run alongside the v0.1.0 suites rather than replacing them.

`swift test --package-path native/FluxdayPersistence` uses temporary real SQLite databases to verify schema setup, atomic replacement, restart persistence, portable JSON, read-only legacy detection and complete v0.1.0 migration.

`swift format lint`, a code-signing-disabled native `xcodebuild`, `npm run lint`, `npm run typecheck`, `npm run format:check` and `npm run build` are required during migration. `npm run tauri build -- --bundles app` continues to verify the released v0.1.0 bundle until parity. UI smoke checks cover first-run import, empty and sample states, operation CRUD/undo, each primary view, narrow/normal/fullscreen layouts, long names, negative balances and large money values.
