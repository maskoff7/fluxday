import type { CalendarDate } from "./types";

const ISO_DATE = /^(\d{4})-(\d{2})-(\d{2})$/;

export interface DateParts {
  year: number;
  month: number;
  day: number;
}

export function daysInMonth(year: number, month: number): number {
  if (month === 2)
    return year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0) ? 29 : 28;
  return [4, 6, 9, 11].includes(month) ? 30 : 31;
}

export function parseCalendarDate(value: unknown): DateParts | null {
  const match = String(value ?? "").match(ISO_DATE);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (year < 1000 || year > 9999 || month < 1 || month > 12) return null;
  if (day < 1 || day > daysInMonth(year, month)) return null;
  return { year, month, day };
}

export function isCalendarDate(value: unknown): value is CalendarDate {
  return parseCalendarDate(value) !== null;
}

export function calendarDate({ year, month, day }: DateParts): CalendarDate {
  return `${String(year).padStart(4, "0")}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

function fromUtcDate(value: Date): CalendarDate {
  return calendarDate({
    year: value.getUTCFullYear(),
    month: value.getUTCMonth() + 1,
    day: value.getUTCDate(),
  });
}

function toUtcDate(value: CalendarDate): Date {
  const parts = parseCalendarDate(value);
  if (!parts) throw new Error(`Invalid calendar date: ${value}`);
  return new Date(Date.UTC(parts.year, parts.month - 1, parts.day));
}

export function todayCalendarDate(now = new Date()): CalendarDate {
  return calendarDate({
    year: now.getFullYear(),
    month: now.getMonth() + 1,
    day: now.getDate(),
  });
}

export function addDays(value: CalendarDate, count: number): CalendarDate {
  const date = toUtcDate(value);
  date.setUTCDate(date.getUTCDate() + count);
  return fromUtcDate(date);
}

export function addMonths(value: CalendarDate, count: number): CalendarDate {
  const parts = parseCalendarDate(value);
  if (!parts) throw new Error(`Invalid calendar date: ${value}`);
  const target = new Date(Date.UTC(parts.year, parts.month - 1 + count, 1));
  return calendarDate({
    year: target.getUTCFullYear(),
    month: target.getUTCMonth() + 1,
    day: Math.min(
      parts.day,
      daysInMonth(target.getUTCFullYear(), target.getUTCMonth() + 1),
    ),
  });
}

export function addYears(value: CalendarDate, count: number): CalendarDate {
  const parts = parseCalendarDate(value);
  if (!parts) throw new Error(`Invalid calendar date: ${value}`);
  const year = parts.year + count;
  return calendarDate({
    year,
    month: parts.month,
    day: Math.min(parts.day, daysInMonth(year, parts.month)),
  });
}

export function startOfMonth(value: CalendarDate): CalendarDate {
  const parts = parseCalendarDate(value);
  if (!parts) throw new Error(`Invalid calendar date: ${value}`);
  return calendarDate({ ...parts, day: 1 });
}

export function endOfMonth(value: CalendarDate): CalendarDate {
  const parts = parseCalendarDate(value);
  if (!parts) throw new Error(`Invalid calendar date: ${value}`);
  return calendarDate({ ...parts, day: daysInMonth(parts.year, parts.month) });
}

export function startOfWeek(value: CalendarDate): CalendarDate {
  const weekday = toUtcDate(value).getUTCDay();
  return addDays(value, -((weekday + 6) % 7));
}

export function endOfWeek(value: CalendarDate): CalendarDate {
  return addDays(startOfWeek(value), 6);
}

export function startOfYear(value: CalendarDate): CalendarDate {
  const parts = parseCalendarDate(value);
  if (!parts) throw new Error(`Invalid calendar date: ${value}`);
  return `${parts.year}-01-01`;
}

export function endOfYear(value: CalendarDate): CalendarDate {
  return `${parseCalendarDate(value)?.year ?? 1970}-12-31`;
}

export function eachDay(
  start: CalendarDate,
  end: CalendarDate,
): CalendarDate[] {
  if (end < start) return [];
  const result: CalendarDate[] = [];
  for (let cursor = start; cursor <= end; cursor = addDays(cursor, 1)) {
    result.push(cursor);
    if (result.length > 40_000)
      throw new Error("Forecast range exceeds 40,000 days");
  }
  return result;
}

export function formatCalendarDate(
  value: CalendarDate,
  options?: Intl.DateTimeFormatOptions,
): string {
  return new Intl.DateTimeFormat("ru-RU", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    timeZone: "UTC",
    ...options,
  }).format(toUtcDate(value));
}

export function defaultRecurrenceEnd(
  value: CalendarDate,
  recurrence: string,
): CalendarDate | null {
  if (recurrence === "none") return null;
  return recurrence === "yearly" ? addYears(value, 1) : addMonths(value, 1);
}
