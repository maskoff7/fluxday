import CashFlowCore
import Foundation

public struct LegacyMigrationPreview: Equatable, Identifiable, Sendable {
  public var id: URL { sourceURL }

  public let sourceURL: URL
  public let plan: CashFlowPlan
  public let operationCount: Int
  public let recurringCount: Int
  public let scenarioCount: Int

  public init(sourceURL: URL, plan: CashFlowPlan) {
    self.sourceURL = sourceURL
    self.plan = plan
    operationCount = plan.operations.count
    recurringCount = plan.operations.filter { $0.recurrence != .none }.count
    scenarioCount = plan.scenarios.count
  }
}

public enum LegacyV01Migration {
  public static func detect(
    at databaseURL: URL? = nil,
    fileManager: FileManager = .default
  ) throws -> LegacyMigrationPreview? {
    let sourceURL = try databaseURL ?? StorageLocations.legacyDatabaseURL(fileManager: fileManager)
    guard fileManager.fileExists(atPath: sourceURL.path) else { return nil }

    let database = try SQLiteDatabase(url: sourceURL, readOnly: true)
    let databaseVersion = try database.userVersion()
    guard databaseVersion <= 1 else {
      throw PersistenceError.unsupportedDatabaseVersion(databaseVersion)
    }
    guard let snapshot = try database.loadLegacySnapshot() else { return nil }
    guard snapshot.schemaVersion == 1 else {
      throw PersistenceError.unsupportedSnapshotVersion(snapshot.schemaVersion)
    }
    return LegacyMigrationPreview(
      sourceURL: sourceURL,
      plan: try PlanDocumentCodec.decode(snapshot.payload)
    )
  }
}
