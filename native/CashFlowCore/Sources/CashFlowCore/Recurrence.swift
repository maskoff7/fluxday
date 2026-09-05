import Foundation

public enum RecurrenceEngine {
  public static let maximumOccurrencesPerOperation = 50_000

  public static func defaultEndDate(
    from firstDate: CalendarDate,
    recurrence: Recurrence
  ) throws -> CalendarDate? {
    switch recurrence {
    case .none:
      nil
    case .yearly:
      try firstDate.adding(years: 1)
    case .daily, .weekly, .monthly:
      try firstDate.adding(months: 1)
    }
  }

  public static func nextOccurrenceDate(
    for operation: Operation,
    onOrAfter date: CalendarDate
  ) throws -> CalendarDate? {
    guard operation.enabled else { return nil }
    if operation.recurrence == .none {
      return operation.firstDate >= date ? operation.firstDate : nil
    }

    var index = firstCandidateIndex(for: operation, rangeStart: date)
    var candidate = try occurrenceDate(for: operation, index: index)
    while candidate < date {
      index += 1
      candidate = try occurrenceDate(for: operation, index: index)
    }

    if let endDate = operation.recurrenceEndDate, candidate > endDate { return nil }
    return candidate
  }

  public static func occurrenceDates(
    for operation: Operation,
    from rangeStart: CalendarDate,
    through rangeEnd: CalendarDate
  ) throws -> [CalendarDate] {
    guard operation.enabled, rangeStart <= rangeEnd else { return [] }

    if operation.recurrence == .none {
      return (rangeStart...rangeEnd).contains(operation.firstDate) ? [operation.firstDate] : []
    }

    let seriesEnd = min(operation.recurrenceEndDate ?? rangeEnd, rangeEnd)
    guard seriesEnd >= operation.firstDate else { return [] }

    let initialIndex = firstCandidateIndex(for: operation, rangeStart: rangeStart)
    var result: [CalendarDate] = []
    var index = initialIndex

    while true {
      let date = try occurrenceDate(for: operation, index: index)
      if date > seriesEnd { break }
      if date >= rangeStart {
        guard result.count < maximumOccurrencesPerOperation else {
          throw CashFlowCoreError.tooManyOccurrences(operationID: operation.id)
        }
        result.append(date)
      }
      if date == seriesEnd { break }
      index += 1
    }

    return result
  }

  public static func expand(
    operations: [Operation],
    from rangeStart: CalendarDate,
    through rangeEnd: CalendarDate
  ) throws -> [Occurrence] {
    var result: [Occurrence] = []
    for operation in operations {
      let dates = try occurrenceDates(for: operation, from: rangeStart, through: rangeEnd)
      result.append(contentsOf: dates.map { Occurrence(operation: operation, date: $0) })
    }
    return result.sorted {
      $0.date != $1.date ? $0.date < $1.date : $0.name < $1.name
    }
  }

  private static func firstCandidateIndex(
    for operation: Operation,
    rangeStart: CalendarDate
  ) -> Int {
    guard operation.firstDate < rangeStart else { return 0 }

    switch operation.recurrence {
    case .none:
      return 0
    case .daily:
      return max(0, operation.firstDate.days(until: rangeStart))
    case .weekly:
      return max(0, operation.firstDate.days(until: rangeStart) / 7)
    case .monthly:
      let months =
        (rangeStart.year - operation.firstDate.year) * 12
        + rangeStart.month - operation.firstDate.month
      return max(0, months - 1)
    case .yearly:
      return max(0, rangeStart.year - operation.firstDate.year - 1)
    }
  }

  private static func occurrenceDate(for operation: Operation, index: Int) throws -> CalendarDate {
    switch operation.recurrence {
    case .none:
      operation.firstDate
    case .daily:
      try operation.firstDate.adding(days: index)
    case .weekly:
      try operation.firstDate.adding(days: index * 7)
    case .monthly:
      try operation.firstDate.adding(months: index)
    case .yearly:
      try operation.firstDate.adding(years: index)
    }
  }
}
