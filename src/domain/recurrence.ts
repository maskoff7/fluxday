import { addDays, addMonths, addYears, isCalendarDate } from "./date";
import type { CalendarDate, Occurrence, Operation } from "./types";

export const MAX_OCCURRENCES_PER_OPERATION = 50_000;

export function occurrenceDates(
  operation: Operation,
  rangeStart: CalendarDate,
  rangeEnd: CalendarDate,
): CalendarDate[] {
  if (
    !operation.enabled ||
    rangeEnd < rangeStart ||
    !isCalendarDate(operation.firstDate)
  )
    return [];
  if (operation.recurrence === "none") {
    return operation.firstDate >= rangeStart && operation.firstDate <= rangeEnd
      ? [operation.firstDate]
      : [];
  }
  const end =
    operation.recurrenceEndDate && operation.recurrenceEndDate < rangeEnd
      ? operation.recurrenceEndDate
      : rangeEnd;
  if (!end || end < operation.firstDate) return [];
  const result: CalendarDate[] = [];
  for (let index = 0; index < MAX_OCCURRENCES_PER_OPERATION; index += 1) {
    const date =
      operation.recurrence === "daily"
        ? addDays(operation.firstDate, index)
        : operation.recurrence === "weekly"
          ? addDays(operation.firstDate, index * 7)
          : operation.recurrence === "monthly"
            ? addMonths(operation.firstDate, index)
            : addYears(operation.firstDate, index);
    if (date > end) break;
    if (date >= rangeStart) result.push(date);
  }
  return result;
}

export function expandOccurrences(
  operations: Operation[],
  rangeStart: CalendarDate,
  rangeEnd: CalendarDate,
): Occurrence[] {
  return operations
    .flatMap((operation) =>
      occurrenceDates(operation, rangeStart, rangeEnd).map((date) => ({
        ...operation,
        sourceId: operation.id,
        date,
        occurrenceId: `${operation.id}:${date}`,
        recurring: operation.recurrence !== "none",
      })),
    )
    .sort(
      (left, right) =>
        left.date.localeCompare(right.date) ||
        left.name.localeCompare(right.name, "ru"),
    );
}
