import CashFlowCore

func date(_ value: String) throws -> CalendarDate {
  try CalendarDate(value)
}

func operation(
  id: String,
  type: OperationType = .expense,
  amountMinor: Int64 = 10_000,
  certainty: Certainty = .certain,
  firstDate: String = "2026-01-02",
  recurrence: Recurrence = .none,
  recurrenceEndDate: String? = nil,
  enabled: Bool = true
) throws -> Operation {
  try Operation(
    id: id,
    name: id,
    type: type,
    amountMinor: Money(minorUnits: amountMinor),
    certainty: certainty,
    firstDate: date(firstDate),
    recurrence: recurrence,
    recurrenceEndDate: recurrenceEndDate.map { try CalendarDate($0) },
    enabled: enabled,
    createdAt: "2026-01-01T00:00:00.000Z",
    updatedAt: "2026-01-01T00:00:00.000Z"
  )
}
