import CashFlowCore
import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

func temporaryDatabaseURL(_ name: String = "fluxday-native.sqlite3") throws -> URL {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("FluxdayPersistenceTests-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  return directory.appendingPathComponent(name)
}

func testPlan() throws -> CashFlowPlan {
  let rent = Operation(
    id: "rent",
    name: "Rent",
    type: .expense,
    amountMinor: Money(minorUnits: 50_025),
    certainty: .certain,
    firstDate: try CalendarDate("2026-01-31"),
    recurrence: .monthly,
    recurrenceEndDate: try CalendarDate("2026-03-31"),
    note: "Preserve me",
    createdAt: "2026-01-01T00:00:00.000Z",
    updatedAt: "2026-01-01T00:00:00.000Z"
  )
  return CashFlowPlan(
    settings: PlanSettings(
      startBalanceMinor: Money(minorUnits: 123_456),
      startDate: try CalendarDate("2026-01-01"),
      preferences: PlanPreferences(onboardingComplete: true)
    ),
    operations: [rent],
    scenarios: [
      Scenario(
        id: "higher-rent",
        name: "Higher rent",
        overrides: [
          "rent": ScenarioOverride(
            amountMinor: Money(minorUnits: 70_050),
            recurrenceEndDate: .some(nil),
            certainty: .expected,
            excluded: false
          )
        ]
      )
    ]
  )
}

func createLegacyDatabase(at url: URL, payload: Data, snapshotVersion: Int32 = 1) throws {
  var handle: OpaquePointer?
  guard
    sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
      == SQLITE_OK,
    let handle
  else {
    throw TestDatabaseError.openFailed
  }
  defer { sqlite3_close(handle) }

  let schema = """
    CREATE TABLE app_state (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      schema_version INTEGER NOT NULL,
      payload TEXT NOT NULL,
      updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    PRAGMA user_version = 1;
    """
  guard sqlite3_exec(handle, schema, nil, nil, nil) == SQLITE_OK else {
    throw TestDatabaseError.schemaFailed
  }

  var statement: OpaquePointer?
  guard
    sqlite3_prepare_v2(
      handle,
      "INSERT INTO app_state (id, schema_version, payload) VALUES (1, ?1, ?2)",
      -1,
      &statement,
      nil
    ) == SQLITE_OK,
    let statement
  else {
    throw TestDatabaseError.prepareFailed
  }
  defer { sqlite3_finalize(statement) }

  guard sqlite3_bind_int(statement, 1, snapshotVersion) == SQLITE_OK else {
    throw TestDatabaseError.bindFailed
  }
  let bindResult = payload.withUnsafeBytes { bytes in
    sqlite3_bind_text(
      statement,
      2,
      bytes.baseAddress?.assumingMemoryBound(to: CChar.self),
      Int32(payload.count),
      sqliteTransient
    )
  }
  guard bindResult == SQLITE_OK, sqlite3_step(statement) == SQLITE_DONE else {
    throw TestDatabaseError.writeFailed
  }
}

enum TestDatabaseError: Error {
  case openFailed
  case schemaFailed
  case prepareFailed
  case bindFailed
  case writeFailed
}
