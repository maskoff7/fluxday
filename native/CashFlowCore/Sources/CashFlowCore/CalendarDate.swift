import Foundation

public struct CalendarDate: Hashable, Comparable, Codable, CustomStringConvertible, Sendable {
  public static let minimumYear = 1_000
  public static let maximumYear = 9_999
  public static let maximumForecastDays = 40_000
  public static let maximumPlanningYears = 100

  public let year: Int
  public let month: Int
  public let day: Int

  public init(year: Int, month: Int, day: Int) throws {
    guard
      (Self.minimumYear...Self.maximumYear).contains(year),
      (1...12).contains(month),
      (1...Self.daysInMonth(year: year, month: month)).contains(day)
    else {
      throw CalendarDateError.invalidDate
    }

    self.year = year
    self.month = month
    self.day = day
  }

  public init(_ iso8601: String) throws {
    let parts = iso8601.split(separator: "-", omittingEmptySubsequences: false)
    guard
      parts.count == 3,
      parts[0].count == 4,
      parts[1].count == 2,
      parts[2].count == 2,
      parts.allSatisfy({ $0.allSatisfy(\.isNumber) }),
      let year = Int(parts[0]),
      let month = Int(parts[1]),
      let day = Int(parts[2])
    else {
      throw CalendarDateError.invalidFormat
    }

    try self.init(year: year, month: month, day: day)
  }

  public static func parse(_ iso8601: String) -> CalendarDate? {
    try? CalendarDate(iso8601)
  }

  public var description: String {
    String(format: "%04d-%02d-%02d", year, month, day)
  }

  public static func < (left: CalendarDate, right: CalendarDate) -> Bool {
    (left.year, left.month, left.day) < (right.year, right.month, right.day)
  }

  public static func isLeapYear(_ year: Int) -> Bool {
    year.isMultiple(of: 4) && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
  }

  public static func daysInMonth(year: Int, month: Int) -> Int {
    switch month {
    case 2:
      isLeapYear(year) ? 29 : 28
    case 4, 6, 9, 11:
      30
    default:
      31
    }
  }

  public func adding(days count: Int) throws -> CalendarDate {
    let (target, overflow) = serialDay.addingReportingOverflow(count)
    guard !overflow else { throw CalendarDateError.outOfRange }
    return try Self(serialDay: target)
  }

  public func adding(months count: Int) throws -> CalendarDate {
    let base = year * 12 + month - 1
    let (target, overflow) = base.addingReportingOverflow(count)
    let minimum = Self.minimumYear * 12
    let maximum = Self.maximumYear * 12 + 11
    guard !overflow, (minimum...maximum).contains(target) else {
      throw CalendarDateError.outOfRange
    }

    let targetYear = target / 12
    let targetMonth = target % 12 + 1
    return try CalendarDate(
      year: targetYear,
      month: targetMonth,
      day: min(day, Self.daysInMonth(year: targetYear, month: targetMonth))
    )
  }

  public func adding(years count: Int) throws -> CalendarDate {
    let (targetYear, overflow) = year.addingReportingOverflow(count)
    guard !overflow, (Self.minimumYear...Self.maximumYear).contains(targetYear) else {
      throw CalendarDateError.outOfRange
    }

    return try CalendarDate(
      year: targetYear,
      month: month,
      day: min(day, Self.daysInMonth(year: targetYear, month: month))
    )
  }

  public func days(until other: CalendarDate) -> Int {
    other.serialDay - serialDay
  }

  public func eachDay(through end: CalendarDate) throws -> [CalendarDate] {
    let distance = days(until: end)
    guard distance >= 0 else { return [] }
    guard distance + 1 <= Self.maximumForecastDays else {
      throw CashFlowCoreError.forecastRangeTooLarge
    }
    return try (0...distance).map { try adding(days: $0) }
  }

  public var startOfMonth: CalendarDate {
    try! CalendarDate(year: year, month: month, day: 1)
  }

  public var endOfMonth: CalendarDate {
    try! CalendarDate(year: year, month: month, day: Self.daysInMonth(year: year, month: month))
  }

  public func monthGridDays() throws -> [CalendarDate] {
    let firstGridDay = try startOfMonth.startOfWeek()
    return try firstGridDay.eachDay(through: firstGridDay.adding(days: 41))
  }

  public func startOfWeek() throws -> CalendarDate {
    let epoch = try! CalendarDate("1970-01-01")
    let daysFromEpoch = epoch.days(until: self)
    let mondayIndex = ((daysFromEpoch + 3) % 7 + 7) % 7
    return try adding(days: -mondayIndex)
  }

  public func endOfWeek() throws -> CalendarDate {
    try startOfWeek().adding(days: 6)
  }

  public var startOfYear: CalendarDate {
    try! CalendarDate(year: year, month: 1, day: 1)
  }

  public var endOfYear: CalendarDate {
    try! CalendarDate(year: year, month: 12, day: 31)
  }

  public var maximumPlanningDate: CalendarDate {
    guard year + Self.maximumPlanningYears <= Self.maximumYear else {
      return try! CalendarDate("9999-12-31")
    }
    return try! adding(years: Self.maximumPlanningYears)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    do {
      try self.init(value)
    } catch {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid Gregorian calendar date"
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }

  private var serialDay: Int {
    var adjustedYear = year
    if month <= 2 { adjustedYear -= 1 }
    let era = adjustedYear / 400
    let yearOfEra = adjustedYear - era * 400
    let shiftedMonth = month + (month > 2 ? -3 : 9)
    let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
    let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
    return era * 146_097 + dayOfEra
  }

  private init(serialDay: Int) throws {
    let era = serialDay / 146_097
    let dayOfEra = serialDay - era * 146_097
    let yearOfEra =
      (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
    var year = yearOfEra + era * 400
    let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
    let shiftedMonth = (5 * dayOfYear + 2) / 153
    let day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
    let month = shiftedMonth + (shiftedMonth < 10 ? 3 : -9)
    year += month <= 2 ? 1 : 0
    try self.init(year: year, month: month, day: day)
  }
}

public enum CalendarDateError: Error, Equatable, Sendable {
  case invalidFormat
  case invalidDate
  case outOfRange
}
