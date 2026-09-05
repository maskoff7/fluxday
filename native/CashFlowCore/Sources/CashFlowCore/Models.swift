import Foundation

public enum OperationType: String, Codable, CaseIterable, Sendable {
  case income
  case expense
}

public enum Certainty: String, Codable, CaseIterable, Sendable {
  case certain
  case expected
}

public enum Recurrence: String, Codable, CaseIterable, Sendable {
  case none
  case daily
  case weekly
  case monthly
  case yearly
}

public struct PlanPreferences: Codable, Equatable, Sendable {
  public var onboardingComplete: Bool

  public init(onboardingComplete: Bool = false) {
    self.onboardingComplete = onboardingComplete
  }
}

public struct PlanSettings: Codable, Equatable, Sendable {
  public var startBalanceMinor: Money
  public var startDate: CalendarDate
  public var baseCurrency: String
  public var preferences: PlanPreferences

  public init(
    startBalanceMinor: Money,
    startDate: CalendarDate,
    baseCurrency: String = "RUB",
    preferences: PlanPreferences = PlanPreferences()
  ) {
    self.startBalanceMinor = startBalanceMinor
    self.startDate = startDate
    self.baseCurrency = baseCurrency
    self.preferences = preferences
  }
}

public struct Operation: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var name: String
  public var type: OperationType
  public var amountMinor: Money
  public var certainty: Certainty
  public var firstDate: CalendarDate
  public var recurrence: Recurrence
  public var recurrenceEndDate: CalendarDate?
  public var note: String
  public var enabled: Bool
  public var createdAt: String
  public var updatedAt: String

  public init(
    id: String,
    name: String,
    type: OperationType,
    amountMinor: Money,
    certainty: Certainty,
    firstDate: CalendarDate,
    recurrence: Recurrence = .none,
    recurrenceEndDate: CalendarDate? = nil,
    note: String = "",
    enabled: Bool = true,
    createdAt: String = "",
    updatedAt: String = ""
  ) {
    self.id = id
    self.name = name
    self.type = type
    self.amountMinor = amountMinor
    self.certainty = certainty
    self.firstDate = firstDate
    self.recurrence = recurrence
    self.recurrenceEndDate = recurrenceEndDate
    self.note = note
    self.enabled = enabled
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public struct ScenarioOverride: Equatable, Sendable {
  public var amountMinor: Money?
  public var recurrence: Recurrence?
  public var firstDate: CalendarDate?
  public var recurrenceEndDate: CalendarDate??
  public var certainty: Certainty?
  public var excluded: Bool?

  public init(
    amountMinor: Money? = nil,
    recurrence: Recurrence? = nil,
    firstDate: CalendarDate? = nil,
    recurrenceEndDate: CalendarDate?? = nil,
    certainty: Certainty? = nil,
    excluded: Bool? = nil
  ) {
    self.amountMinor = amountMinor
    self.recurrence = recurrence
    self.firstDate = firstDate
    self.recurrenceEndDate = recurrenceEndDate
    self.certainty = certainty
    self.excluded = excluded
  }
}

extension ScenarioOverride: Codable {
  private enum CodingKeys: String, CodingKey {
    case amountMinor
    case recurrence
    case firstDate
    case recurrenceEndDate
    case certainty
    case excluded
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    amountMinor = try container.decodeIfPresent(Money.self, forKey: .amountMinor)
    recurrence = try container.decodeIfPresent(Recurrence.self, forKey: .recurrence)
    firstDate = try container.decodeIfPresent(CalendarDate.self, forKey: .firstDate)
    if container.contains(.recurrenceEndDate) {
      recurrenceEndDate = .some(
        try container.decodeIfPresent(CalendarDate.self, forKey: .recurrenceEndDate)
      )
    } else {
      recurrenceEndDate = nil
    }
    certainty = try container.decodeIfPresent(Certainty.self, forKey: .certainty)
    excluded = try container.decodeIfPresent(Bool.self, forKey: .excluded)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(amountMinor, forKey: .amountMinor)
    try container.encodeIfPresent(recurrence, forKey: .recurrence)
    try container.encodeIfPresent(firstDate, forKey: .firstDate)
    if let endDate = recurrenceEndDate {
      if let endDate {
        try container.encode(endDate, forKey: .recurrenceEndDate)
      } else {
        try container.encodeNil(forKey: .recurrenceEndDate)
      }
    }
    try container.encodeIfPresent(certainty, forKey: .certainty)
    try container.encodeIfPresent(excluded, forKey: .excluded)
  }
}

public struct Scenario: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var name: String
  public var overrides: [String: ScenarioOverride]

  public init(id: String, name: String, overrides: [String: ScenarioOverride] = [:]) {
    self.id = id
    self.name = name
    self.overrides = overrides
  }
}

public struct CashFlowPlan: Codable, Equatable, Sendable {
  public var schemaVersion: Int
  public var settings: PlanSettings
  public var operations: [Operation]
  public var scenarios: [Scenario]

  public init(
    schemaVersion: Int = 1,
    settings: PlanSettings,
    operations: [Operation] = [],
    scenarios: [Scenario] = []
  ) {
    self.schemaVersion = schemaVersion
    self.settings = settings
    self.operations = operations
    self.scenarios = scenarios
  }
}

public struct Occurrence: Equatable, Identifiable, Sendable {
  public let operation: Operation
  public let date: CalendarDate

  public var id: String { "\(operation.id):\(date)" }
  public var sourceID: String { operation.id }
  public var isRecurring: Bool { operation.recurrence != .none }
  public var name: String { operation.name }
  public var type: OperationType { operation.type }
  public var amountMinor: Money { operation.amountMinor }
  public var certainty: Certainty { operation.certainty }

  public init(operation: Operation, date: CalendarDate) {
    self.operation = operation
    self.date = date
  }
}
