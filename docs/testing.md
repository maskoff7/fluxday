# Testing

`swift test --package-path native/CashFlowCore` verifies checked minor-unit arithmetic, invalid and leap-year dates, anchored monthly and yearly recurrence, long ranges, daily forecasts, closing-balance cash gaps, expected-income stress mode, scenario immutability, summaries, and the v0.1.0 golden JSON fixture.

`swift test --package-path native/FluxdayPersistence` uses temporary real SQLite databases to verify schema setup, atomic replacement, restart persistence across store instances, portable backup round trips, read-only legacy detection, and complete v0.1.0 migration. Tests never use the production application-support database.

The native GitHub Actions gate runs strict Swift formatting, both test packages, English/Russian String Catalog validation, and a code-signing-disabled Xcode build. Release branches additionally produce and inspect an unsigned universal application, ZIP, and DMG on a GitHub-hosted macOS runner.

Visual QA uses deterministic in-memory Debug fixtures. Most verification should be non-interactive or hosted in CI. Real window activation is reserved for behavior that cannot be checked reliably off-screen, such as menus, focus, sheets, hover, keyboard shortcuts, VoiceOver interaction, and final window resizing. Those checks are grouped into a single end-of-increment pass.

The release matrix covers every primary view, English and Russian, Light and Dark Mode, compact and normal windows, long names, large values, negative balances, empty states, operation editing, Undo/Redo, migration preview, and backup restore. A successful check is not repeated unless relevant UI changes afterward.
