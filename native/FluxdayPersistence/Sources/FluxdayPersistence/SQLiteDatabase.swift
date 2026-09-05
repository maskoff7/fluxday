import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SQLiteDatabase {
  private var handle: OpaquePointer?

  init(url: URL, readOnly: Bool = false) throws {
    var database: OpaquePointer?
    let flags =
      readOnly
      ? SQLITE_OPEN_READONLY
      : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
    let result = sqlite3_open_v2(url.path, &database, flags, nil)
    guard result == SQLITE_OK, let database else {
      let message =
        database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open database"
      if let database { sqlite3_close(database) }
      throw PersistenceError.sqlite(code: result, message: message)
    }
    handle = database
    try execute("PRAGMA busy_timeout = 5000")
    if !readOnly {
      try execute("PRAGMA journal_mode = WAL")
      try execute("PRAGMA synchronous = NORMAL")
      try execute("PRAGMA foreign_keys = ON")
    }
  }

  deinit {
    if let handle { sqlite3_close(handle) }
  }

  func execute(_ sql: String) throws {
    guard let handle else { throw databaseClosedError() }
    var errorMessage: UnsafeMutablePointer<CChar>?
    let result = sqlite3_exec(handle, sql, nil, nil, &errorMessage)
    guard result == SQLITE_OK else {
      let message =
        errorMessage.map { String(cString: $0) }
        ?? String(cString: sqlite3_errmsg(handle))
      sqlite3_free(errorMessage)
      throw PersistenceError.sqlite(code: result, message: message)
    }
  }

  func userVersion() throws -> Int32 {
    let statement = try prepare("PRAGMA user_version")
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_ROW else { throw lastError() }
    return sqlite3_column_int(statement, 0)
  }

  func loadSnapshot() throws -> Data? {
    let statement = try prepare("SELECT payload FROM plan_snapshot WHERE id = 1")
    defer { sqlite3_finalize(statement) }
    let result = sqlite3_step(statement)
    if result == SQLITE_DONE { return nil }
    guard result == SQLITE_ROW else { throw lastError(code: result) }
    return data(in: statement, column: 0)
  }

  func saveSnapshot(_ data: Data, schemaVersion: Int) throws {
    guard data.count <= Int(Int32.max) else { throw PersistenceError.dataTooLarge }
    try transaction {
      let statement = try prepare(
        """
        INSERT INTO plan_snapshot (id, schema_version, payload, updated_at)
        VALUES (1, ?1, ?2, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
        ON CONFLICT(id) DO UPDATE SET
          schema_version = excluded.schema_version,
          payload = excluded.payload,
          updated_at = excluded.updated_at
        """
      )
      defer { sqlite3_finalize(statement) }
      guard sqlite3_bind_int(statement, 1, Int32(schemaVersion)) == SQLITE_OK else {
        throw lastError()
      }
      let bindResult = data.withUnsafeBytes { bytes in
        sqlite3_bind_blob(
          statement,
          2,
          bytes.baseAddress,
          Int32(data.count),
          sqliteTransient
        )
      }
      guard bindResult == SQLITE_OK else { throw lastError(code: bindResult) }
      let result = sqlite3_step(statement)
      guard result == SQLITE_DONE else { throw lastError(code: result) }
    }
  }

  func containsSnapshot() throws -> Bool {
    let statement = try prepare("SELECT EXISTS(SELECT 1 FROM plan_snapshot WHERE id = 1)")
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_ROW else { throw lastError() }
    return sqlite3_column_int(statement, 0) == 1
  }

  func loadLegacySnapshot() throws -> (schemaVersion: Int32, payload: Data)? {
    let statement = try prepare("SELECT schema_version, payload FROM app_state WHERE id = 1")
    defer { sqlite3_finalize(statement) }
    let result = sqlite3_step(statement)
    if result == SQLITE_DONE { return nil }
    guard result == SQLITE_ROW else { throw lastError(code: result) }
    return (sqlite3_column_int(statement, 0), data(in: statement, column: 1))
  }

  private func prepare(_ sql: String) throws -> OpaquePointer {
    guard let handle else { throw databaseClosedError() }
    var statement: OpaquePointer?
    let result = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
    guard result == SQLITE_OK, let statement else { throw lastError(code: result) }
    return statement
  }

  private func data(in statement: OpaquePointer, column: Int32) -> Data {
    let count = Int(sqlite3_column_bytes(statement, column))
    guard count > 0, let bytes = sqlite3_column_blob(statement, column) else { return Data() }
    return Data(bytes: bytes, count: count)
  }

  private func transaction(_ body: () throws -> Void) throws {
    try execute("BEGIN IMMEDIATE")
    do {
      try body()
      try execute("COMMIT")
    } catch {
      try? execute("ROLLBACK")
      throw error
    }
  }

  private func lastError(code: Int32? = nil) -> PersistenceError {
    guard let handle else { return databaseClosedError() }
    return PersistenceError.sqlite(
      code: code ?? sqlite3_errcode(handle),
      message: String(cString: sqlite3_errmsg(handle))
    )
  }

  private func databaseClosedError() -> PersistenceError {
    PersistenceError.sqlite(code: SQLITE_MISUSE, message: "Database is closed")
  }
}
