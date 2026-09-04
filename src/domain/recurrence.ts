import {
  addDays,
  addMonths,
  addYears,
  daysBetween,
  isCalendarDate,
  parseCalendarDate,
} from "./date";
import type { CalendarDate, Occurrence, Operation } from "./types";

export const MAX_OCCURRENCES_PER_OPERATION = 50_000;

function firstCandidateIndex(
  operation: Operation,
  rangeStart: CalendarDate,
): number {
  if (operation.firstDate >= rangeStart) return 0;
  if (operation.recurrence === "daily")
    return Math.max(0, daysBetween(operation.firstDate, rangeStart));
  if (operation.recurrence === "weekly")
    return Math.max(
      0,
      Math.floor(daysBetween(operation.firstDate, rangeStart) / 7),
    );
  const first = parseCalendarDate(operation.firstDate)!;
  const range = parseCalendarDate(rangeStart)!;
  return operation.recurrence === "monthly"
    ? Math.max(
        0,
        (range.year - first.year) * 12 + range.month - first.month - 1,
      )
    : Math.max(0, range.year - first.year - 1);
}

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
  const initialIndex = firstCandidateIndex(operation, rangeStart);
  for (let offset = 0; offset <= MAX_OCCURRENCES_PER_OPERATION; offset += 1) {
    if (offset === MAX_OCCURRENCES_PER_OPERATION) {
      throw new Error(
        `Серия «${operation.name}» содержит больше ${MAX_OCCURRENCES_PER_OPERATION.toLocaleString("ru-RU")} операций в горизонте.`,
      );
    }
    const index = initialIndex + offset;
    const date =
      operation.recurrence === "daily"
        ? addDays(operation.firstDate, index)
        : operation.recurrence === "weekly"
          ? addDays(operation.firstDate, index * 7)
          : operation.recurrence === "monthly"
            ? addMonths(operation.firstDate, index)
            : addYears(operation.firstDate, index);
    if (!isCalendarDate(date)) break;
    if (date > end) break;
    if (date >= rangeStart) result.push(date);
    if (date === end) break;
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
