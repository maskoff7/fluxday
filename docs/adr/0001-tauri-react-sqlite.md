# ADR 0001: Tauri, React and SQLite

Status: accepted.

Tauri 2, React and TypeScript are retained from the requested strategy. Tauri provides a small cross-platform native shell; React suits the interactive planner views; SQLite supplies durable local storage without a service. Electron was rejected because its bundled browser/runtime cost adds no product value here. Native SwiftUI was rejected because a Windows release would require a second UI.

The database stores an atomic JSON snapshot rather than normalized rows. This keeps persistence and migration code small while the dataset is personal and forecast calculations require the whole plan in memory. Normalized tables should be introduced only if measured scale or partial-query needs justify the extra synchronization surface.
