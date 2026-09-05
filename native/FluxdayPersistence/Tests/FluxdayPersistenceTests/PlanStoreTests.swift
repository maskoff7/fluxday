import CashFlowCore
import FluxdayPersistence
import Foundation
import XCTest

final class PlanStoreTests: XCTestCase {
  func testPersistsAndRestoresPlanAcrossStoreInstances() async throws {
    let url = try temporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let plan = try testPlan()

    let store = try PlanStore(databaseURL: url)
    try await store.save(plan)
    let reopened = try PlanStore(databaseURL: url)
    let schemaVersion = try await reopened.databaseSchemaVersion()
    let restored = try await reopened.load()

    XCTAssertEqual(schemaVersion, 1)
    XCTAssertEqual(restored, plan)
  }

  func testMigrationIsIdempotentAndSaveReplacesTheSingleSnapshot() async throws {
    let url = try temporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    var updated = try testPlan()
    updated.settings.startBalanceMinor = Money(minorUnits: 999_999)

    let first = try PlanStore(databaseURL: url)
    try await first.save(testPlan())
    try await first.save(updated)
    let second = try PlanStore(databaseURL: url)
    let schemaVersion = try await second.databaseSchemaVersion()
    let restored = try await second.load()

    XCTAssertEqual(schemaVersion, 1)
    XCTAssertEqual(restored, updated)
  }

  func testInvalidSaveLeavesThePreviousSnapshotIntact() async throws {
    let url = try temporaryDatabaseURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let original = try testPlan()
    var invalid = original
    invalid.operations[0].amountMinor = Money(minorUnits: -1)
    let store = try PlanStore(databaseURL: url)
    try await store.save(original)

    do {
      try await store.save(invalid)
      XCTFail("Expected validation to fail")
    } catch {
      XCTAssertEqual(error as? PlanValidationError, .invalidOperationAmount("rent"))
    }
    let restored = try await store.load()
    XCTAssertEqual(restored, original)
  }
}
