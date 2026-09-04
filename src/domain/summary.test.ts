import { expect, it } from "vitest";
import { buildSummary } from "./summary";
import type { Operation } from "./types";

it("aggregates recurring occurrences by source operation", () => {
  const operation: Operation = {
    id: "weekly",
    name: "Weekly",
    type: "expense",
    amountMinor: 10_00,
    certainty: "certain",
    firstDate: "2026-01-01",
    recurrence: "weekly",
    recurrenceEndDate: "2026-01-31",
    note: "",
    enabled: true,
    createdAt: "",
    updatedAt: "",
  };
  const summary = buildSummary([operation], "2026-01-01", "2026-01-31");
  expect(summary.occurrenceCount).toBe(5);
  expect(summary.expenseMinor).toBe(50_00);
  expect(summary.groups[0]).toMatchObject({
    count: 5,
    totalMinor: 50_00,
    share: 1,
  });
});
