import CashFlowCore
import FluxdayPersistence
import Foundation
import XCTest

final class LegacyMigrationTests: XCTestCase {
  func testDetectsAndImportsV01WithoutModifyingTheSource() async throws {
    let legacyURL = try temporaryDatabaseURL("fluxday.sqlite3")
    defer { try? FileManager.default.removeItem(at: legacyURL.deletingLastPathComponent()) }
    let plan = try testPlan()
    let payload = try JSONEncoder().encode(plan)
    try createLegacyDatabase(at: legacyURL, payload: payload)
    let sourceBefore = try Data(contentsOf: legacyURL)

    let preview = try XCTUnwrap(LegacyV01Migration.detect(at: legacyURL))

    XCTAssertEqual(preview.plan, plan)
    XCTAssertEqual(preview.operationCount, 1)
    XCTAssertEqual(preview.recurringCount, 1)
    XCTAssertEqual(preview.scenarioCount, 1)
    XCTAssertEqual(try Data(contentsOf: legacyURL), sourceBefore)

    let destinationURL = legacyURL.deletingLastPathComponent()
      .appendingPathComponent("fluxday-native.sqlite3")
    let store = try PlanStore(databaseURL: destinationURL)
    try await store.importLegacy(preview)
    let restored = try await store.load()
    XCTAssertEqual(restored, plan)
    XCTAssertEqual(try Data(contentsOf: legacyURL), sourceBefore)

    do {
      try await store.importLegacy(preview)
      XCTFail("Expected a non-empty destination to require explicit replacement")
    } catch {
      XCTAssertEqual(error as? PersistenceError, .destinationNotEmpty)
    }
  }

  func testRejectsCorruptLegacyPayloadWithoutChangingIt() throws {
    let legacyURL = try temporaryDatabaseURL("fluxday.sqlite3")
    defer { try? FileManager.default.removeItem(at: legacyURL.deletingLastPathComponent()) }
    try createLegacyDatabase(at: legacyURL, payload: Data("not-json".utf8))
    let sourceBefore = try Data(contentsOf: legacyURL)

    XCTAssertThrowsError(try LegacyV01Migration.detect(at: legacyURL)) { error in
      XCTAssertEqual(error as? PersistenceError, .invalidDocument)
    }
    XCTAssertEqual(try Data(contentsOf: legacyURL), sourceBefore)
  }

  func testReturnsNilWhenNoLegacyDatabaseExists() throws {
    let missingURL = try temporaryDatabaseURL("missing.sqlite3")
    defer { try? FileManager.default.removeItem(at: missingURL.deletingLastPathComponent()) }
    XCTAssertNil(try LegacyV01Migration.detect(at: missingURL))
  }
}
