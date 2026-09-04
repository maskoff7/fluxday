# Fluxday 0.1.0 — macOS MVP

The first local-first release answers the core question: when does the projected daily closing balance become negative, by how much, and which nearby operations caused it?

## Included

- operation CRUD, duplication, search and undo;
- anchored daily, weekly, monthly and yearly recurrence;
- timeline, calendar, closing-balance and summary views;
- explained “without expected income” stress test;
- sparse Base vs Scenario comparisons for recurring series;
- cash-gap cause panel and scenario shortcut;
- SQLite autosave with transactional migration;
- JSON import preview, export, backup and legacy migration;
- keyboard shortcuts, light/dark appearance and responsive layouts.

## Distribution

The local `.app` build is unsigned. Public distribution still requires an Apple Developer certificate, notarization credentials and the corresponding GitHub secrets. The release workflow is prepared to attach macOS artifacts created from a `v*` tag.
