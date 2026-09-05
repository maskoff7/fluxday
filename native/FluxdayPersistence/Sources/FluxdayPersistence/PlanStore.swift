import CashFlowCore
import Foundation

public actor PlanStore {
  public static let schemaVersion: Int32 = 1

  public let databaseURL: URL
  private let database: SQLiteDatabase

  public init(databaseURL: URL) throws {
    self.databaseURL = databaseURL
    try FileManager.default.createDirectory(
      at: databaseURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    database = try SQLiteDatabase(url: databaseURL)
    try Self.migrate(database)
    _ = try database.containsSnapshot()
  }

  public func load() throws -> CashFlowPlan? {
    guard let data = try database.loadSnapshot() else { return nil }
    return try PlanDocumentCodec.decode(data)
  }

  public func save(_ plan: CashFlowPlan) throws {
    try PlanValidator.validate(plan)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    try database.saveSnapshot(encoder.encode(plan), schemaVersion: plan.schemaVersion)
  }

  public func importLegacy(
    _ preview: LegacyMigrationPreview,
    replacingExisting: Bool = false
  ) throws {
    if !replacingExisting, try database.containsSnapshot() {
      throw PersistenceError.destinationNotEmpty
    }
    try save(preview.plan)
  }

  public func databaseSchemaVersion() throws -> Int32 {
    try database.userVersion()
  }

  private static func migrate(_ database: SQLiteDatabase) throws {
    let current = try database.userVersion()
    guard current <= schemaVersion else {
      throw PersistenceError.unsupportedDatabaseVersion(current)
    }
    if current < 1 {
      try database.execute(
        """
        BEGIN IMMEDIATE;
        CREATE TABLE IF NOT EXISTS plan_snapshot (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          schema_version INTEGER NOT NULL,
          payload BLOB NOT NULL,
          updated_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS migration_history (
          version INTEGER PRIMARY KEY,
          applied_at TEXT NOT NULL
        );
        INSERT OR IGNORE INTO migration_history (version, applied_at)
        VALUES (1, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'));
        PRAGMA user_version = 1;
        COMMIT;
        """
      )
    }
  }
}
