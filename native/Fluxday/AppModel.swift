import CashFlowCore
import Combine
import FluxdayPersistence
import Foundation

private enum AppModelTransferError: Error {
  case persistenceUnavailable
}

@MainActor
final class AppModel: ObservableObject {
  @Published private(set) var plan = AppModel.emptyPlan()
  @Published private(set) var forecast: Forecast?
  @Published var migrationPreview: LegacyMigrationPreview?
  @Published private(set) var isLoading = false
  @Published private(set) var isMigrating = false
  @Published private(set) var isCalculating = false
  @Published var showsPersistenceError = false
  @Published var showsCalculationError = false

  private var store: PlanStore?
  private var hasStarted = false
  private var forecastRevision = 0
  private var forecastTask: Task<Void, Never>?
  private var pendingSave: Task<Void, Never>?

  func start() async {
    guard !hasStarted else { return }
    hasStarted = true
    isLoading = true
    defer { isLoading = false }

    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("--demo") {
        plan = Self.demoPlan()
        refreshForecast()
        return
      }
    #endif

    do {
      let databaseURL = try StorageLocations.nativeDatabaseURL()
      let store = try await Task.detached(priority: .userInitiated) {
        try PlanStore(databaseURL: databaseURL)
      }.value
      self.store = store

      if let storedPlan = try await store.load() {
        plan = storedPlan
        refreshForecast()
      } else {
        refreshForecast()
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
      refreshForecast()
    } catch {
      showsPersistenceError = true
    }
  }

  func dismissMigration() {
    migrationPreview = nil
  }

  func saveOperation(_ operation: CashFlowCore.Operation) {
    var updated = plan
    if let index = updated.operations.firstIndex(where: { $0.id == operation.id }) {
      updated.operations[index] = operation
    } else {
      updated.operations.append(operation)
    }
    commit(updated)
  }

  func deleteOperation(_ operation: CashFlowCore.Operation) {
    var updated = plan
    updated.operations.removeAll { $0.id == operation.id }
    for index in updated.scenarios.indices {
      updated.scenarios[index].overrides.removeValue(forKey: operation.id)
    }
    commit(updated)
  }

  func toggleOperation(_ operation: CashFlowCore.Operation) {
    guard let index = plan.operations.firstIndex(where: { $0.id == operation.id }) else { return }
    var updated = plan
    updated.operations[index].enabled.toggle()
    updated.operations[index].updatedAt = ISO8601DateFormatter().string(from: Date())
    commit(updated)
  }

  func updateStartingPoint(balance: Money, date: CalendarDate) {
    var updated = plan
    updated.settings.startBalanceMinor = balance
    updated.settings.startDate = date
    commit(updated)
  }

  func saveScenario(_ scenario: Scenario) {
    var updated = plan
    if let index = updated.scenarios.firstIndex(where: { $0.id == scenario.id }) {
      updated.scenarios[index] = scenario
    } else {
      updated.scenarios.append(scenario)
    }
    commit(updated, recalculatesForecast: false)
  }

  func deleteScenario(id: String) {
    var updated = plan
    updated.scenarios.removeAll { $0.id == id }
    commit(updated, recalculatesForecast: false)
  }

  func updateScenarioOverride(
    scenarioID: String,
    operationID: String,
    override: ScenarioOverride?
  ) {
    guard let index = plan.scenarios.firstIndex(where: { $0.id == scenarioID }) else { return }
    var updated = plan
    if let override {
      updated.scenarios[index].overrides[operationID] = override
    } else {
      updated.scenarios[index].overrides.removeValue(forKey: operationID)
    }
    commit(updated, recalculatesForecast: false)
  }

  func backupData() async throws -> Data {
    let snapshot = plan
    return try await Task.detached(priority: .userInitiated) {
      try PlanDocumentCodec.encode(snapshot)
    }.value
  }

  func restoreBackup(from url: URL) async throws {
    let hasSecurityAccess = url.startAccessingSecurityScopedResource()
    defer {
      if hasSecurityAccess { url.stopAccessingSecurityScopedResource() }
    }

    let restored = try await Task.detached(priority: .userInitiated) {
      try PlanDocumentCodec.decode(Data(contentsOf: url, options: .mappedIfSafe))
    }.value

    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("--demo") {
        plan = restored
        refreshForecast()
        return
      }
    #endif

    guard let store else { throw AppModelTransferError.persistenceUnavailable }
    await pendingSave?.value
    try await store.save(restored)
    plan = restored
    refreshForecast()
  }

  private func commit(_ updated: CashFlowPlan, recalculatesForecast: Bool = true) {
    do {
      try PlanValidator.validate(updated)
    } catch {
      showsPersistenceError = true
      return
    }
    plan = updated
    if recalculatesForecast { refreshForecast() }
    persist(updated)
  }

  private func persist(_ snapshot: CashFlowPlan) {
    guard let store else { return }
    let previousSave = pendingSave
    pendingSave = Task { [weak self] in
      await previousSave?.value
      do {
        try await store.save(snapshot)
      } catch {
        self?.showsPersistenceError = true
      }
    }
  }

  private func refreshForecast() {
    forecastRevision += 1
    let revision = forecastRevision
    let snapshot = plan
    forecastTask?.cancel()
    isCalculating = true
    forecastTask = Task { [weak self] in
      let result = await Task.detached(priority: .userInitiated) {
        Result {
          try ForecastEngine.build(
            startingBalance: snapshot.settings.startBalanceMinor,
            startDate: snapshot.settings.startDate,
            operations: snapshot.operations
          )
        }
      }.value
      guard let self, revision == forecastRevision, !Task.isCancelled else { return }
      isCalculating = false
      switch result {
      case .success(let value):
        forecast = value
      case .failure:
        forecast = nil
        showsCalculationError = true
      }
    }
  }

  private static func emptyPlan() -> CashFlowPlan {
    CashFlowPlan(
      settings: PlanSettings(
        startBalanceMinor: .zero,
        startDate: today()
      )
    )
  }

  #if DEBUG
    private static func demoPlan() -> CashFlowPlan {
      let today = today()
      let timestamp = ISO8601DateFormatter().string(from: Date())
      func operation(
        _ id: String,
        _ name: String,
        _ type: OperationType,
        _ amount: Int64,
        _ days: Int,
        recurrence: Recurrence = .none,
        endMonths: Int? = nil,
        certainty: Certainty = .certain
      ) -> CashFlowCore.Operation {
        let firstDate = try! today.adding(days: days)
        return CashFlowCore.Operation(
          id: id,
          name: name,
          type: type,
          amountMinor: Money(minorUnits: amount),
          certainty: certainty,
          firstDate: firstDate,
          recurrence: recurrence,
          recurrenceEndDate: endMonths.map { try! firstDate.adding(months: $0) },
          createdAt: timestamp,
          updatedAt: timestamp
        )
      }
      let salary = operation(
        "salary", "Salary", .income, 185_000_00, 3, recurrence: .monthly, endMonths: 6)
      let rent = operation(
        "rent", "Apartment rent", .expense, 78_000_00, 1, recurrence: .monthly, endMonths: 6)
      let operations = [
        salary,
        rent,
        operation("subscription", "Annual software subscription", .expense, 42_000_00, 14),
        operation(
          "project", "Freelance project", .income, 90_000_00, 35, certainty: .expected),
        operation("tax", "Quarterly tax", .expense, 105_000_00, 72),
      ]
      let higherRent = Scenario(
        id: "higher-rent",
        name: "Higher rent",
        overrides: ["rent": ScenarioOverride(amountMinor: Money(minorUnits: 92_000_00))]
      )
      let delayedSalary = Scenario(
        id: "delayed-salary",
        name: "Salary arrives later",
        overrides: [
          "salary": ScenarioOverride(firstDate: try! salary.firstDate.adding(days: 10))
        ]
      )
      return CashFlowPlan(
        settings: PlanSettings(
          startBalanceMinor: Money(minorUnits: 65_000_00),
          startDate: today
        ),
        operations: operations,
        scenarios: [higherRent, delayedSalary]
      )
    }
  #endif

  private static func today() -> CalendarDate {
    let components = Calendar.autoupdatingCurrent.dateComponents(
      [.year, .month, .day], from: Date())
    return try! CalendarDate(
      year: components.year ?? 2_000,
      month: components.month ?? 1,
      day: components.day ?? 1
    )
  }
}
