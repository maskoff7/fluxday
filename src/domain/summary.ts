import { expandOccurrences } from "./recurrence";
import type { CalendarDate, Operation, Summary, SummaryGroup } from "./types";

export type SummaryFilter = "expense" | "income" | "all";

export function buildSummary(
  operations: Operation[],
  start: CalendarDate,
  end: CalendarDate,
  filter: SummaryFilter = "all",
): Summary {
  const occurrences = expandOccurrences(operations, start, end);
  const incomeMinor = occurrences
    .filter((item) => item.type === "income")
    .reduce((total, item) => total + item.amountMinor, 0);
  const expenseMinor = occurrences
    .filter((item) => item.type === "expense")
    .reduce((total, item) => total + item.amountMinor, 0);
  const visible =
    filter === "all"
      ? occurrences
      : occurrences.filter((item) => item.type === filter);
  const totalVisible = visible.reduce(
    (total, item) => total + item.amountMinor,
    0,
  );
  const groups = new Map<string, SummaryGroup>();
  for (const occurrence of visible) {
    const existing = groups.get(occurrence.sourceId) ?? {
      id: occurrence.sourceId,
      name: occurrence.name,
      type: occurrence.type,
      certainty: occurrence.certainty,
      recurrence: occurrence.recurrence,
      totalMinor: 0,
      count: 0,
      share: 0,
      occurrences: [],
    };
    existing.totalMinor += occurrence.amountMinor;
    existing.count += 1;
    existing.occurrences.push(occurrence);
    groups.set(occurrence.sourceId, existing);
  }
  const sorted = [...groups.values()].sort(
    (left, right) =>
      right.totalMinor - left.totalMinor ||
      left.name.localeCompare(right.name, "ru"),
  );
  for (const group of sorted)
    group.share = totalVisible === 0 ? 0 : group.totalMinor / totalVisible;
  return {
    incomeMinor,
    expenseMinor,
    netMinor: incomeMinor - expenseMinor,
    turnoverMinor: incomeMinor + expenseMinor,
    occurrenceCount: occurrences.length,
    groups: sorted,
  };
}
