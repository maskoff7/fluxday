import CashFlowCore
import Combine
import FluxdayPersistence
import Foundation

@MainActor
final class AppModel: ObservableObject {
  @Published private(set) var plan = AppModel.emptyPlan()
  @Published var migrationPreview: LegacyMigrationPreview?
  @Published private(set) var isLoading = false
  @Published private(set) var isMigrating = false
  @Published var showsPersistenceError = false

  private var store: PlanStore?
  private var hasStarted = false

  func start() async {
    guard !hasStarted else { return }
    hasStarted = true
    isLoading = true
    defer { isLoading = false }

    do {
      let databaseURL = try StorageLocations.nativeDatabaseURL()
      let store = try await Task.detached(priority: .userInitiated) {
        try PlanStore(databaseURL: databaseURL)
      }.value
      self.store = store

      if let storedPlan = try await store.load() {
        plan = storedPlan
      } else {
        migrationPreview = try await Task.detached(priority: .userInitiated) {
          try LegacyV01Migration.detect()
        }.value
      }
    } catch {
      showsPersistenceError = true
    }
  }

  func confirmMigration() async {
    guard let store, let migrationPreview else { return }
    isMigrating = true
    defer { isMigrating = false }

    do {
      try await store.importLegacy(migrationPreview)
      plan = migrationPreview.plan
      self.migrationPreview = nil
    } catch {
      showsPersistenceError = true
    }
  }

  func dismissMigration() {
    migrationPreview = nil
  }

  private static func emptyPlan() -> CashFlowPlan {
    let components = Calendar.autoupdatingCurrent.dateComponents(
      [.year, .month, .day], from: Date())
    let today = try? CalendarDate(
      year: components.year ?? 2_000,
      month: components.month ?? 1,
      day: components.day ?? 1
    )
    return CashFlowPlan(
      settings: PlanSettings(
        startBalanceMinor: .zero,
        startDate: today ?? (try! CalendarDate("2000-01-01"))
      )
    )
  }
}
