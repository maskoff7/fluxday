# Data model

All money fields end in `Minor` and contain integer kopecks. `CalendarDate` is a validated `YYYY-MM-DD` string.

- `Settings`: start balance, start date, base currency (`RUB`) and preferences.
- `Operation`: stable id, name, type, amount, certainty, first date, recurrence, optional inclusive end date, note, enabled flag and created/updated timestamps.
- `Scenario`: id, name and sparse overrides keyed by recurring-operation id.
- `ScenarioOverride`: optional amount/frequency/first/end/certainty plus exclusion.
- `AppState`: schema version, settings, operations and scenarios.

The database stores one normalized `AppState` JSON snapshot in `app_state(id = 1)`. This is deliberate: personal datasets are small, all forecast queries are in-memory, and a single-row upsert gives transactional persistence without maintaining parallel relational and in-memory models. Future migrations may normalize high-volume tables if measured data sizes require it.
