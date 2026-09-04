# Architecture

Fluxday is a local-first Tauri 2 desktop application with React 19, TypeScript, Vite and SQLite. The web layer owns presentation and pure financial domain logic; Rust owns the native lifecycle and durable local snapshot store.

```text
React views → application state → pure domain engines
                    ↓
             storage adapter
             ↙           ↘
      Tauri commands    localStorage
             ↓          (browser dev)
        SQLite snapshot
```

Money is represented as safe integer minor units. Financial dates are validated `YYYY-MM-DD` calendar values and arithmetic uses UTC calendar components, never timestamps. Recurrence expansion, forecasting, stress calculation, summaries and scenario overlays are deterministic pure functions.

The SQLite database lives in Tauri's application-data directory. Schema migrations run transactionally at startup. The entire validated state is stored as one JSON document in a single-row table, making every autosave an atomic upsert and keeping import replacement safe. The domain still models settings, operations and scenarios independently; normalization is the boundary between untrusted JSON and persisted state.

Browser development intentionally falls back to local storage so visual work and component tests do not require a native shell. Production builds use only SQLite. No network client, account, telemetry or analytics code is included.
