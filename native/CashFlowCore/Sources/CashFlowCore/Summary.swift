import Foundation

public enum SummaryFilter: String, CaseIterable, Sendable {
  case expense
  case income
  case all
}

public struct SummaryGroup: Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let type: OperationType
  public let certainty: Certainty
  public let recurrence: Recurrence
  public let totalMinor: Money
  public let count: Int
  public let share: Double
  public let occurrences: [Occurrence]
}

public struct Summary: Equatable, Sendable {
  public let incomeMinor: Money
  public let expenseMinor: Money
  public let netMinor: Money
  public let turnoverMinor: Money
  public let occurrenceCount: Int
  public let groups: [SummaryGroup]
}

public enum SummaryEngine {
  public static func build(
    operations: [Operation],
    from startDate: CalendarDate,
    through endDate: CalendarDate,
    filter: SummaryFilter = .all
  ) throws -> Summary {
    let occurrences = try RecurrenceEngine.expand(
      operations: operations,
      from: startDate,
      through: endDate
    )
    var income: Int64 = 0
    var expense: Int64 = 0

    for occurrence in occurrences {
      if occurrence.type == .income {
        income = try checkedAdd(income, occurrence.amountMinor.minorUnits)
      } else {
        expense = try checkedAdd(expense, occurrence.amountMinor.minorUnits)
      }
    }

    let visible =
      filter == .all ? occurrences : occurrences.filter { $0.type.rawValue == filter.rawValue }
    var grouped = Dictionary(grouping: visible, by: \.sourceID)
    let totalVisible = try visible.reduce(Int64(0)) {
      try checkedAdd($0, $1.amountMinor.minorUnits)
    }

    var groups: [SummaryGroup] = []
    for operation in operations where grouped[operation.id] != nil {
      let groupOccurrences = grouped.removeValue(forKey: operation.id) ?? []
      let total = try groupOccurrences.reduce(Int64(0)) {
        try checkedAdd($0, $1.amountMinor.minorUnits)
      }
      groups.append(
        SummaryGroup(
          id: operation.id,
          name: operation.name,
          type: operation.type,
          certainty: operation.certainty,
          recurrence: operation.recurrence,
          totalMinor: Money(minorUnits: total),
          count: groupOccurrences.count,
          share: totalVisible == 0 ? 0 : Double(total) / Double(totalVisible),
          occurrences: groupOccurrences
        )
      )
    }
    groups.sort {
      $0.totalMinor != $1.totalMinor ? $0.totalMinor > $1.totalMinor : $0.name < $1.name
    }

    return Summary(
      incomeMinor: Money(minorUnits: income),
      expenseMinor: Money(minorUnits: expense),
      netMinor: Money(minorUnits: try checkedSubtract(income, expense)),
      turnoverMinor: Money(minorUnits: try checkedAdd(income, expense)),
      occurrenceCount: occurrences.count,
      groups: groups
    )
  }
}
